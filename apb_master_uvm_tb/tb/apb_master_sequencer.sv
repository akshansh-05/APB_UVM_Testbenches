// ============================================================================
// FILE: apb_master_sequencer.sv
// DESCRIPTION:
//   Sequencer for the APB Master testbench.
//   Same concept as the slave TB — a FIFO between Sequences and the Driver.
// ============================================================================

typedef uvm_sequencer #(apb_master_seq_item) apb_master_sequencer;
