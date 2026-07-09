class slave_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(slave_driver)

  virtual apb_if vif;

  // Wait-state knob, hardcoded for now. 0 = zero-wait (PREADY stays HIGH).
  int unsigned wait_states = 0;

  // Golden memory model, 9-bit address space
  logic [7:0] mem [logic [8:0]];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("SLV_DRV", "Virtual interface not set for slave_driver")
  endfunction

  task run_phase(uvm_phase phase);
    reset_signals();

    forever begin
      @(vif.slave_cb);

      // SETUP phase: PSEL asserted, PENABLE low
      if ((vif.slave_cb.PSEL1 === 1'b1 || vif.slave_cb.PSEL2 === 1'b1) &&
           vif.slave_cb.PENABLE === 1'b0) begin
        respond_access();
      end
    end
  endtask

  // PREADY parked HIGH (always-ready). PRDATA cleared.
  task reset_signals();
    vif.slave_cb.PREADY <= 1'b1;
    vif.slave_cb.PRDATA <= '0;
  endtask

  task respond_access();
    // We are in SETUP. For reads, present data now so it's valid at ACCESS.
    if (vif.slave_cb.PWRITE === 1'b0) begin
      logic [7:0] rdata;
      rdata = mem.exists(vif.slave_cb.PADDR) ? mem[vif.slave_cb.PADDR] : '0;
      vif.slave_cb.PRDATA <= rdata;
    end

    // Advance to ACCESS phase (master raises PENABLE)
    @(vif.slave_cb);

    // Inject wait states: pull PREADY low for N cycles now that PENABLE is high
    for (int i = 0; i < wait_states; i++) begin
      vif.slave_cb.PREADY <= 1'b0;
      @(vif.slave_cb);
    end

    // Loop exited -> PREADY HIGH, handshake completes this cycle
    vif.slave_cb.PREADY <= 1'b1;

    // Service the access at completion
    if (vif.slave_cb.PWRITE === 1'b1) begin
      mem[vif.slave_cb.PADDR] <= vif.slave_cb.PWDATA;
      `uvm_info("SLV_DRV",
        $sformatf("APB HANDSHAKE COMPLETE | WRITE addr=0x%0h data=0x%0h",
                  vif.slave_cb.PADDR, vif.slave_cb.PWDATA),
        UVM_MEDIUM)
    end
    else begin
      `uvm_info("SLV_DRV",
        $sformatf("APB HANDSHAKE COMPLETE | READ  addr=0x%0h data=0x%0h",
                  vif.slave_cb.PADDR, vif.slave_cb.PRDATA),
        UVM_MEDIUM)
    end
  endtask

endclass