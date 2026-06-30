class apb_slv_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(apb_slv_driver)
  virtual apb_if vif;

  // Associative array: only written addresses exist
  logic [7:0] slave_mem [bit[8:0]];

  // Wait states to insert per access (set from test/config)
  int wait_cycles = 1;

  function new(string name = "apb_slv_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SLV_DRV", "Could not get virtual interface 'vif'")
  endfunction

  task run_phase(uvm_phase phase);
    // Idle defaults
    vif.slave_cb.PREADY <= 1'b1;
    vif.slave_cb.PRDATA <= '0;

    forever begin
      @(vif.slave_cb);

      // Re-init on reset, then skip this cycle
      if (vif.PRESETn !== 1'b1) begin
        vif.slave_cb.PREADY <= 1'b1;
        vif.slave_cb.PRDATA <= '0;
        continue;
      end

      // Detect the start of a transfer: SETUP phase (PSEL high, PENABLE low)
      if ((vif.slave_cb.PSEL1 || vif.slave_cb.PSEL2) && !vif.slave_cb.PENABLE) begin

        // Insert wait states: hold PREADY low so the master stalls in ENABLE
        repeat (wait_cycles) begin
          vif.slave_cb.PREADY <= 1'b0;
          @(vif.slave_cb);
        end

        // Drive the response for the completing cycle
        vif.slave_cb.PREADY <= 1'b1;
        if (vif.slave_cb.PWRITE)
          slave_mem[vif.slave_cb.PADDR] = vif.slave_cb.PWDATA;
        else
          vif.slave_cb.PRDATA <= slave_mem.exists(vif.slave_cb.PADDR)
                                   ? slave_mem[vif.slave_cb.PADDR] : 8'h00;

        // Completion cycle: keep PREADY/PRDATA stable while master samples
        @(vif.slave_cb);
      end
    end
  endtask
endclass