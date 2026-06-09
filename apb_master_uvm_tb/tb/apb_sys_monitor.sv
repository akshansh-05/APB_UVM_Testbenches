// The system monitor samples host-side command requests to create expected
// transactions for scoreboard comparison.
class apb_sys_monitor extends uvm_monitor;

  `uvm_component_utils(apb_sys_monitor)

  virtual apb_if vif;

  uvm_analysis_port #(apb_seq_item) ap;

    // Constructor: standard UVM component/object constructor initializing the parent and name
  function new(string name = "apb_sys_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction

    // Build Phase: instantiate sub-components, ports, and retrieve virtual interfaces from config_db
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SYS_MON", "Could not get virtual interface 'vif' from config_db")
  endfunction

    // Run Phase: main simulation execution loop handling active driving or passive monitoring
  task run_phase(uvm_phase phase);
    forever begin
      @(vif.sys_monitor_cb);
      if (vif.sys_monitor_cb.transfer === 1'b1 && vif.PRESETn === 1'b1) begin
        apb_seq_item item;
        item = apb_seq_item::type_id::create("item");

        item.read = vif.sys_monitor_cb.READ_WRITE;
        if (item.read) begin
          item.addr = vif.sys_monitor_cb.apb_read_paddr;
        end
        else begin
          item.addr  = vif.sys_monitor_cb.apb_write_paddr;
          item.wdata = vif.sys_monitor_cb.apb_write_data;
        end

        while (!vif.sys_monitor_cb.PREADY) begin
          @(vif.sys_monitor_cb);
        end

        if (item.read)
          item.rdata = vif.sys_monitor_cb.apb_read_data_out;

        `uvm_info("SYS_MON", $sformatf("Captured System Expected Request: addr=0x%03h read=%0b data=0x%02h", item.addr, item.read, item.read ? item.rdata : item.wdata), UVM_MEDIUM)

        ap.write(item);
      end
    end
  endtask

endclass
