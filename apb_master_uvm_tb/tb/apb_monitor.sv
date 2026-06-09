class apb_monitor extends uvm_monitor;

  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;

  uvm_analysis_port #(apb_seq_item) ap;

  function new(string name = "apb_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("MON", "Could not get virtual interface 'vif' from config_db")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(vif.monitor_cb);
      // Capture the bus transaction when a valid handshake completes (PENABLE and PREADY are high) on an active slave select (PSEL1 or PSEL2)
      if (vif.monitor_cb.PENABLE === 1'b1 && vif.monitor_cb.PREADY === 1'b1 && (vif.monitor_cb.PSEL1 === 1'b1 || vif.monitor_cb.PSEL2 === 1'b1)) begin
        apb_seq_item item;
        item = apb_seq_item::type_id::create("item");

        item.paddr   = vif.monitor_cb.PADDR;
        item.pwdata  = vif.monitor_cb.PWDATA;
        item.pwrite  = vif.monitor_cb.PWRITE;
        item.rdata   = vif.monitor_cb.PRDATA;
        item.psel1   = vif.monitor_cb.PSEL1;
        item.psel2   = vif.monitor_cb.PSEL2;
        item.penable = vif.monitor_cb.PENABLE;
        item.pslverr = vif.monitor_cb.PSLVERR;

        `uvm_info("MON", $sformatf("Captured APB Bus Transaction: addr=0x%03h pwrite=%0b data=0x%02h", item.paddr, item.pwrite, item.pwrite ? item.pwdata : item.rdata), UVM_MEDIUM)

        ap.write(item);
      end
    end
  endtask

endclass
