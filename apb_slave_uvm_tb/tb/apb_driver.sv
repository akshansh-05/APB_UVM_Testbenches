//     - Assert PSEL = 1
//     - Drive PADDR, PWDATA, PWRITE
//     - Keep PENABLE = 0
//   Cycle 2 (ACCESS phase):
//     - Assert PENABLE = 1

class apb_driver extends uvm_driver #(apb_seq_item);

  `uvm_component_utils(apb_driver)

  virtual apb_if.driver vif;

  function new(string name = "apb_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "Could not get virtual interface 'vif' from config_db")
  endfunction

  task run_phase(uvm_phase phase);

    vif.driver_cb.PSEL    <= 0;
    vif.driver_cb.PENABLE <= 0;
    vif.driver_cb.PADDR   <= 0;
    vif.driver_cb.PWDATA  <= 0;
    vif.driver_cb.PWRITE  <= 0;

    forever begin // Infinite loop to fetch items as long as sequences are running
      apb_seq_item item;

      seq_item_port.get_next_item(item);

      `uvm_info("DRV", $sformatf("Driving: %s", item.convert2string()), UVM_MEDIUM)

      @(vif.driver_cb); // Synchronize with the next active clock edge
      vif.driver_cb.PSEL    <= 1; // Assert PSEL (select this slave)
      vif.driver_cb.PENABLE <= 0;
      vif.driver_cb.PADDR   <= item.addr; // Drive target address to PADDR
      vif.driver_cb.PWRITE  <= item.write; // Drive write/read mode control
      if (item.write)
        vif.driver_cb.PWDATA <= item.wdata;

      // Step 3: ACCESS phase (one clock later)
      @(vif.driver_cb);
      vif.driver_cb.PENABLE <= 1;

      // In this DUT, PREADY goes high combinationally with PENABLE,
      @(vif.driver_cb);
      while (!vif.driver_cb.PREADY) begin // Loop if slave holds PREADY low (wait states)
        @(vif.driver_cb);
      end

      if (!item.write) begin
        item.rdata = vif.driver_cb.PRDATA1;
      end

      vif.driver_cb.PSEL    <= 0;
      vif.driver_cb.PENABLE <= 0;

      seq_item_port.item_done();
    end
  endtask

endclass
