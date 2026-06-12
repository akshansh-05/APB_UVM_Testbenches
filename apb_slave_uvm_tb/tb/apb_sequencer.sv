`include "uvm_macros.svh"
import uvm_pkg::*;

// Alias parameterizing the standard UVM sequencer with our transaction sequence item.
typedef uvm_sequencer #(apb_seq_item) apb_sequencer;
