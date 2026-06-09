// ============================================================================
// FILE: apb_sys_monitor.sv
// DESCRIPTION: Passive system-side monitor for the APB Master TB
// ============================================================================

class apb_sys_monitor extends uvm_monitor;               // Extends the base UVM monitor class

  // ---- UVM FACTORY REGISTER ----
  `uvm_component_utils(apb_sys_monitor)                  // Registers class with factory

  // ---- VIRTUAL INTERFACE HANDLE ----
  virtual apb_if vif;                                    // Virtual interface handle

  // ---- TLM ANALYSIS PORT ----
  uvm_analysis_port #(apb_seq_item) ap;                  // Analysis port to broadcast captured system transfers

  // ---- CONSTRUCTOR METHOD ----
  function new(string name = "apb_sys_monitor", uvm_component parent); // Constructor taking name and parent
    super.new(name, parent);                             // Calls parent base class constructor
  endfunction                                            // End of constructor declaration

  // ---- UVM BUILD PHASE ----
  function void build_phase(uvm_phase phase);            // Build phase callback
    super.build_phase(phase);                            // Calls parent build phase
    ap = new("ap", this);                                // Instantiates the analysis port object
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif)) // Retrieves interface handle from database
      `uvm_fatal("SYS_MON", "Could not get virtual interface 'vif' from config_db") // Throws fatal error if not found
  endfunction                                            // End of build phase declaration

  // ---- UVM RUN PHASE ----
  task run_phase(uvm_phase phase);                       // Run phase time-consuming task
    forever begin                                        // Infinite monitor loop
      @(vif.sys_monitor_cb);                             // Syncs to rising clock edge
      if (vif.sys_monitor_cb.transfer === 1'b1 && vif.PRESETn === 1'b1) begin // Checks for active transfer request when not in reset
        apb_seq_item item;                               // Transaction packet handle
        item = apb_seq_item::type_id::create("item");    // Creates new transaction packet via factory

        item.read = vif.sys_monitor_cb.READ_WRITE;       // Captures system read/write direction flag
        if (item.read) begin                             // Checks if current transfer is a read
          item.addr = vif.sys_monitor_cb.apb_read_paddr; // Captures read address request from system
        end                                              // End of read address capture block
        else begin                                       // Handles write direction capture
          item.addr  = vif.sys_monitor_cb.apb_write_paddr;// Captures write address request from system
          item.wdata = vif.sys_monitor_cb.apb_write_data; // Captures write data request from system
        end                                              // End of write address and data capture block

        while (!vif.sys_monitor_cb.PREADY) begin         // Wait loop until ready handshake occurs on bus
          @(vif.sys_monitor_cb);                         // Syncs to next clock edge to poll PREADY
        end                                              // End of handshake wait loop

        if (item.read)                                   // Checks if the completed transaction was a read command
          item.rdata = vif.sys_monitor_cb.apb_read_data_out; // Samples read data output returned by Master DUT

        `uvm_info("SYS_MON", $sformatf("Captured System Expected Request: addr=0x%03h read=%0b data=0x%02h", item.addr, item.read, item.read ? item.rdata : item.wdata), UVM_MEDIUM) // Prints debug info to log

        ap.write(item);                                  // Broadcasts completed expected transaction to scoreboard
      end                                                // End of active transfer check block
    end                                                  // End of forever loop block
  endtask                                                // End of run phase task declaration

endclass // End of apb_sys_monitor class declaration
