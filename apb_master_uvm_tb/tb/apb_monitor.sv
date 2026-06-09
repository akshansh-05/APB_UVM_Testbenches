// ============================================================================
// FILE: apb_monitor.sv
// DESCRIPTION: Standalone APB bus-side monitor for the APB Master TB
// ============================================================================

class apb_monitor extends uvm_monitor;                   // Extends the standard UVM monitor base class

  // ---- UVM FACTORY REGISTER ----
  `uvm_component_utils(apb_monitor)                     // Registers class with factory

  // ---- VIRTUAL INTERFACE HANDLE ----
  virtual apb_if vif;                                    // Virtual interface handle

  // ---- TLM ANALYSIS PORT ----
  uvm_analysis_port #(apb_seq_item) ap;                  // Analysis port to broadcast observed bus transfers

  // ---- CONSTRUCTOR METHOD ----
  function new(string name = "apb_monitor", uvm_component parent); // Constructor taking name and parent
    super.new(name, parent);                             // Calls parent base class constructor
  endfunction                                            // End of constructor declaration

  // ---- UVM BUILD PHASE ----
  function void build_phase(uvm_phase phase);            // Build phase callback
    super.build_phase(phase);                            // Calls parent build phase
    ap = new("ap", this);                                // Instantiates the analysis port object
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif)) // Retrieves interface handle from database
      `uvm_fatal("MON", "Could not get virtual interface 'vif' from config_db") // Throws fatal error if not found
  endfunction                                            // End of build phase declaration

  // ---- UVM RUN PHASE ----
  task run_phase(uvm_phase phase);                       // Run phase time-consuming task
    forever begin                                        // Infinite monitor loop
      @(vif.monitor_cb);                                 // Syncs to rising clock edge (samples inputs)
      if (vif.monitor_cb.PENABLE === 1'b1 && vif.monitor_cb.PREADY === 1'b1 && (vif.monitor_cb.PSEL1 === 1'b1 || vif.monitor_cb.PSEL2 === 1'b1)) begin // Handshake complete when PENABLE, PREADY, and either PSEL1 or PSEL2 is active
        apb_seq_item item;                               // Transaction packet handle
        item = apb_seq_item::type_id::create("item");    // Creates new transaction packet via factory

        item.paddr   = vif.monitor_cb.PADDR;             // Captures address on the APB bus
        item.pwdata  = vif.monitor_cb.PWDATA;            // Captures write data driven on the APB bus
        item.pwrite  = vif.monitor_cb.PWRITE;            // Captures APB direction flag (1=Write, 0=Read)
        item.rdata   = vif.monitor_cb.PRDATA;            // Captures read data driven by slave onto the bus
        item.psel1   = vif.monitor_cb.PSEL1;             // Captures Slave 1 select line state
        item.psel2   = vif.monitor_cb.PSEL2;             // Captures Slave 2 select line state
        item.penable = vif.monitor_cb.PENABLE;           // Captures Enable strobe status
        item.pslverr = vif.monitor_cb.PSLVERR;           // Captures active-high slave error flag

        `uvm_info("MON", $sformatf("Captured APB Bus Transaction: addr=0x%03h pwrite=%0b data=0x%02h", item.paddr, item.pwrite, item.pwrite ? item.pwdata : item.rdata), UVM_MEDIUM) // Prints debug transaction details to log

        ap.write(item);                                  // Broadcasts captured transaction packet to scoreboard
      end                                                // End of active handshake check block
    end                                                  // End of forever loop block
  endtask                                                // End of run phase task declaration

endclass // End of apb_monitor class declaration
