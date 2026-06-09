class apb_slv_driver extends uvm_driver #(apb_seq_item);

  `uvm_component_utils(apb_slv_driver)

  virtual apb_if vif;

  protected bit [7:0] slave_mem [bit [8:0]];             // Local associative array acting as reactive slave RAM

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

    @(vif.slave_cb);
    vif.slave_cb.PREADY <= 1'b0;
    vif.slave_cb.PRDATA <= 8'h00;

    forever begin                                        // Infinite reactive responder loop
      @(vif.slave_cb);

      if (vif.slave_cb.PSEL1 || vif.slave_cb.PSEL2) begin
        if (!vif.slave_cb.PENABLE) begin
          vif.slave_cb.PREADY <= 1'b1;
          if (!vif.slave_cb.PWRITE) begin
            if (slave_mem.exists(vif.slave_cb.PADDR)) begin
              vif.slave_cb.PRDATA <= slave_mem[vif.slave_cb.PADDR];
              `uvm_info("SLV_DRV", $sformatf("Local RAM Read Hit: Addr=0x%03h, Data=0x%02h", vif.slave_cb.PADDR, slave_mem[vif.slave_cb.PADDR]), UVM_HIGH)
            end
            else begin
              bit [7:0] fallback_data = vif.slave_cb.PADDR[7:0] ^ 8'hA5; // Computes predictable fallback pattern from address
              vif.slave_cb.PRDATA <= fallback_data;
              `uvm_info("SLV_DRV", $sformatf("Local RAM Read Miss: Addr=0x%03h, Fallback Data=0x%02h", vif.slave_cb.PADDR, fallback_data), UVM_HIGH)
            end
          end
        end
        else if (vif.slave_cb.PENABLE && vif.slave_cb.PREADY) begin
          if (vif.slave_cb.PWRITE) begin
            slave_mem[vif.slave_cb.PADDR] = vif.slave_cb.PWDATA; // Saves write data into local associative array RAM
            `uvm_info("SLV_DRV", $sformatf("Local RAM Write Captured: Addr=0x%03h, Data=0x%02h", vif.slave_cb.PADDR, vif.slave_cb.PWDATA), UVM_HIGH)
          end
          vif.slave_cb.PREADY <= 1'b0;
        end
      end                                                // End active chip select block
      else begin
        vif.slave_cb.PREADY <= 1'b0;                     // Holds PREADY deasserted when idle
      end
    end
  endtask

endclass
