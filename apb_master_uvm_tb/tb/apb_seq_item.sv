class apb_seq_item extends uvm_sequence_item;

  rand bit [8:0] addr;                                        // 9-bit randomized address; bit[8] selects slave, bits[7:0] target offset
  rand bit [7:0] wdata;
  rand bit       read;

  bit [8:0] paddr;
  bit [7:0] pwdata;
  bit       pwrite;
  bit [7:0] rdata;
  bit       psel1;                                            // Chip select for Slave 1 observed directly on the APB bus
  bit       psel2;                                            // Chip select for Slave 2 observed directly on the APB bus
  bit       penable;
  bit       pslverr;

  constraint c_valid_addr { addr inside {[0:511]}; }

  `uvm_object_utils_begin(apb_seq_item)
    `uvm_field_int(addr,    UVM_ALL_ON)
    `uvm_field_int(wdata,   UVM_ALL_ON)
    `uvm_field_int(read,    UVM_ALL_ON)
    `uvm_field_int(paddr,   UVM_ALL_ON)
    `uvm_field_int(pwdata,  UVM_ALL_ON)
    `uvm_field_int(pwrite,  UVM_ALL_ON)
    `uvm_field_int(rdata,   UVM_ALL_ON)
    `uvm_field_int(psel1,   UVM_ALL_ON)
    `uvm_field_int(psel2,   UVM_ALL_ON)
    `uvm_field_int(penable, UVM_ALL_ON)
    `uvm_field_int(pslverr, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("addr=0x%03h wdata=0x%02h read=%0b | paddr=0x%03h pwdata=0x%02h pwrite=%0b rdata=0x%02h psel1=%0b psel2=%0b penable=%0b pslverr=%0b",
                     addr, wdata, read, paddr, pwdata, pwrite, rdata, psel1, psel2, penable, pslverr);
  endfunction

endclass
