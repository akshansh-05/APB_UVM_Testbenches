// ============================================================================
// FILE: apb_sequencer.sv
// DESCRIPTION:
//   The Sequencer is a "mailbox" that sits between Sequences and the Driver.
//
//   HOW IT WORKS:
//   1. A Sequence generates apb_seq_item transactions.
//   2. The Sequencer queues them up.
//   3. The Driver pulls one item at a time from the Sequencer and drives it.
//
//   For most designs, the default uvm_sequencer is sufficient.
//   We just need to tell it what type of items it handles (apb_seq_item).
// ============================================================================

typedef uvm_sequencer #(apb_seq_item) apb_sequencer;
