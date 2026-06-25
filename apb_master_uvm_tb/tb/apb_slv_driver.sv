`include "uvm_macros.svh"
import uvm_pkg::*;

class apb_slv_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(apb_slv_driver)
  virtual apb_if vif;
  bit [7:0] slave_mem [bit [8:0]];

  function new(string name = "apb_slv_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SLV_DRV", "Could not get virtual interface 'vif' from config_db")
  endfunction

  task run_phase(uvm_phase phase);
    wait(vif.PRESETn === 1'b1);
    vif.slave_cb.PREADY <= 1'b0;
    vif.slave_cb.PRDATA <= 8'h00;

    forever begin
      @(vif.slave_cb);

      // Detect SETUP phase: PSELx asserted, PENABLE still low
      if ((vif.slave_cb.PSEL1 || vif.slave_cb.PSEL2) && !vif.slave_cb.PENABLE) begin

        // For reads: pre-fetch data onto PRDATA during SETUP
        // DUT latches PRDATA during ENABLE, so it must be stable before then
        if (!vif.slave_cb.PWRITE) begin
          if (slave_mem.exists(vif.slave_cb.PADDR))
            vif.slave_cb.PRDATA <= slave_mem[vif.slave_cb.PADDR];
          else
            vif.slave_cb.PRDATA <= 8'h00; // default for unwritten addresses
        end

        // Zero-wait-state: assert PREADY during SETUP so it's seen in ACCESS
        vif.slave_cb.PREADY <= 1'b1;

        // Move to ACCESS phase
        @(vif.slave_cb);

        // ACCESS: PENABLE should be high now, PREADY is already high
        if (vif.slave_cb.PENABLE && vif.PREADY) begin
          if (vif.slave_cb.PWRITE) begin
            slave_mem[vif.slave_cb.PADDR] = vif.slave_cb.PWDATA;
            `uvm_info("SLV_DRV", $sformatf("WRITE: mem[0x%03h] = 0x%02h",
                      vif.slave_cb.PADDR, vif.slave_cb.PWDATA), UVM_LOW)
          end else begin
            `uvm_info("SLV_DRV", $sformatf("READ: mem[0x%03h] => 0x%02h",
                      vif.slave_cb.PADDR, slave_mem[vif.slave_cb.PADDR]), UVM_LOW)
          end
        end

        // Cleanup: deassert after handshake
        vif.slave_cb.PREADY <= 1'b0;
        vif.slave_cb.PRDATA <= 8'h00;

      end else begin
        // No valid SETUP — keep lines idle
        vif.slave_cb.PREADY <= 1'b0;
      end
    end
  endtask
endclass