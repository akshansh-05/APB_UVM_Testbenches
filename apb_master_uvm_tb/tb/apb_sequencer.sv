// ============================================================================
// FILE: apb_sequencer.sv
// DESCRIPTION: Sequencer for the APB Master testbench.
// ============================================================================

// Parameterize the base sequencer with our transaction type.
typedef uvm_sequencer #(apb_seq_item) apb_sequencer;          // Creates the apb_sequencer alias for uvm_sequencer #(apb_seq_item)
