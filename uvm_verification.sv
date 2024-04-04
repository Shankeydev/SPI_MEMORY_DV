`include "uvm_macros.svh"
import uvm_pkg::*;

typedef enum bit [1:0] {wrseq = 0, rdseq = 1, wrseqerr = 2, rdseqerr = 3} test_mode;

class transaction extends uvm_sequence_item;
  `uvm_object_utils(transaction)
  
  rand bit[7:0] data_in;
  bit[7:0] data_out;
  bit wr;
  randc bit[7:0] addr_in;
  bit done,err;
  test_mode tm;
  
  constraint cons1 {addr_in < 5;}
  constraint cons2 {addr_in > 32;}
  
  function new(string path = "TRANS");
    super.new(path);
  endfunction
endclass

///////////////////////////////////////////////////////////////////////////////////

class seq1 extends uvm_sequence #(transaction);
  `uvm_object_utils(seq1)
  
  transaction t;
  
  function new(string path = "seq1");
    super.new(path);
  endfunction
  
  task body();
    repeat(5)
      begin
        t = transaction::type_id::create("TRANS");
        start_item(t);
        t.cons1.constraint_mode(1);
        t.cons2.constraint_mode(0);
        assert(t.randomize());
        t.wr = 1'b1;
        t.tm = wrseq;
        finish_item(t);
      end
  endtask
endclass

//////////////////////////////////////////////////////////////////////////////////////

class seq2 extends uvm_sequence #(transaction);
  `uvm_object_utils(seq2)
  
  transaction t;
  
  function new(string path = "seq2");
    super.new(path);
  endfunction
  
  task body();
    repeat(5)
      begin
        t = transaction::type_id::create("TRANS");
        start_item(t);
        t.cons1.constraint_mode(1);
        t.cons2.constraint_mode(0);
        assert(t.randomize());
        t.wr = 1'b0;
        t.data_in = 8'd0;
        t.tm = rdseq;
        finish_item(t);
      end
  endtask
endclass

//////////////////////////////////////////////////////////////////////////////////////////////

class seq3 extends uvm_sequence #(transaction);
  `uvm_object_utils(seq3)
  
  transaction t;
  
  function new(string path = "seq3");
    super.new(path);
  endfunction
  
  task body();
    repeat(5)
      begin
        t = transaction::type_id::create("TRANS");
        start_item(t);
        t.cons1.constraint_mode(0);
        t.cons2.constraint_mode(1);
        assert(t.randomize());
        t.wr = 1'b1;
        t.tm = wrseqerr;
        finish_item(t);
      end
  endtask
endclass

//////////////////////////////////////////////////////////////////////////////////////////////

class seq4 extends uvm_sequence #(transaction);
  `uvm_object_utils(seq4)
  
  transaction t;
  
  function new(string path = "seq4");
    super.new(path);
  endfunction
  
  task body();
    repeat(5)
      begin
        t = transaction::type_id::create("TRANS");
        start_item(t);
        t.cons1.constraint_mode(0);
        t.cons2.constraint_mode(1);
        assert(t.randomize());
        t.wr = 1'b0;
        t.tm = rdseqerr;
        finish_item(t);
      end
  endtask
endclass

////////////////////////////////////////////////////////////////////////////////////////////

class driver extends uvm_driver #(transaction);
  `uvm_component_utils(driver)
  
  transaction t;
  virtual spi_if sif;
  
  function new(string path = "DRV", uvm_component parent = null);
    super.new(path,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    t = transaction::type_id::create("TRANS");
    if (!uvm_config_db #(virtual spi_if)::get(this,"","sif",sif))
      begin
        `uvm_error("DRV","interface is not accesable")
      end
  endfunction
  
  task reset_dut();
    sif.rst <= 1'b1;
    @(posedge sif.clk);
    @(posedge sif.clk);
    sif.rst <= 1'b0;
    sif.data_in <= 8'b00000000;
    sif.addr_in <= 8'b00000000;
    
  endtask
  
  virtual task run_phase(uvm_phase phase);
    reset_dut();
    @(negedge sif.rst);
    
    forever begin
      seq_item_port.get_next_item(t);
      sif.data_in <= t.data_in;
      sif.addr_in <= t.addr_in;
      sif.wr <= t.wr;
      `uvm_info("DRV",$sformatf("data_in = %0d",t.data_in), UVM_NONE)
      `uvm_info("DRV",$sformatf("addr_in = %0d",t.addr_in), UVM_NONE)
      `uvm_info("DRV",$sformatf("mode = %0d",t.wr), UVM_NONE)
      `uvm_info("DRV",$sformatf("seq_type = %0s",t.tm), UVM_NONE)
      @(posedge sif.clk);
      @(posedge sif.done);
      seq_item_port.item_done();
    end
  endtask
endclass

/////////////////////////////////////////////////////////////////////////////////////////

class monitor extends uvm_monitor;
  `uvm_component_utils(monitor)
  
  transaction t;
  virtual spi_if sif;
  uvm_analysis_port #(transaction) send;
  
  function new(string path = "MON", uvm_component parent = null);
    super.new(path,parent);
  endfunction
  
   virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    t = transaction::type_id::create("TRANS");
     send = new("send", this);
    if (!uvm_config_db #(virtual spi_if)::get(this,"","sif",sif))
      begin
        `uvm_error("MON","interface is not accesable")
      end
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    @(negedge sif.rst);
    forever begin
      @(posedge sif.clk);
      @(posedge sif.done);
      t.data_out = sif.data_out;
      t.done = sif.done;
      t.err = sif.err;
      t.addr_in = sif.addr_in;
      t.data_in = sif.data_in;
      t.wr = sif.wr;
      send.write(t);
    end
  endtask
endclass

/////////////////////////////////////////////////////////////////////////////////

class scoreboard extends uvm_scoreboard;
  `uvm_component_utils(scoreboard)
  
  transaction t;
  uvm_analysis_imp #(transaction,scoreboard) recv;
  
  reg [7:0]addr[32];
  
  function new(string path = "SB", uvm_component parent = null);
    super.new(path,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    recv = new("recv", this);
  endfunction
  
  virtual function void write(transaction t);
    this.t = t;
    if (t.wr) begin
    if (t.err)
        $display("Error: address out of range of memory");
    else begin
        // Code block when t.err is false
        addr[t.addr_in] = t.data_in;
        `uvm_info("SB", $sformatf("addr = %0d :: data = %0d :: data written = %0d", t.addr_in, t.data_in, addr[t.addr_in]), UVM_NONE);
    end
end
else begin
    if (t.err)
        $display("Error: address out of range of memory");
    else begin
        // Nested if-else block
        if (addr[t.addr_in] == t.data_out) begin
            // Code block when condition is true
            $display("----------------------------------------");
            $display("data of the dut = %0d data in memory = %0d", t.data_out, addr[t.addr_in]);
            $display("********TESTPASSED*********");
            $display("----------------------------------------");
        end
        else begin
            // Code block when condition is false
            $display("----------------------------------------");
            $display("data of the dut = %0d data in memory = %0d", t.data_out, addr[t.addr_in]);
            $display("********TESTFAILED*********");
            $display("----------------------------------------");
        end
    end
end

    
  endfunction
endclass

///////////////////////////////////////////////////////////////////////////////////////

class agent extends uvm_agent;
  `uvm_component_utils(agent)
  
  driver d;
  monitor m;
  uvm_sequencer #(transaction) seqr;
  
  function new(string path = "agent", uvm_component parent = null);
    super.new(path,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    d = driver::type_id::create("driver",this);
    m = monitor::type_id::create("monitor",this);
    seqr = uvm_sequencer #(transaction)::type_id::create("seqr",this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    d.seq_item_port.connect(seqr.seq_item_export);
  endfunction
endclass

////////////////////////////////////////////////////////////////////////////////

class env extends uvm_env;
  `uvm_component_utils(env)
  
  scoreboard sb;
  agent a;
  
  function new(string path = "env", uvm_component parent = null);
    super.new(path,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sb = scoreboard::type_id::create("SB", this);
    a = agent::type_id::create("agent",this);
  endfunction
  
  virtual function void connect_phase (uvm_phase phase);
    super.connect_phase(phase);
    a.m.send.connect(sb.recv);
  endfunction
  
endclass

////////////////////////////////////////////////////////////////////////////////

class test extends uvm_test;
  `uvm_component_utils(test)
  
  env e;
  seq1 s1;
  seq2 s2;
  seq3 s3;
  seq4 s4;
  
  function new(string path = "test", uvm_component parent = null);
    super.new(path,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    e = env::type_id::create("env", this);
    s1 = seq1::type_id::create("seq1");
    s2 = seq2::type_id::create("seq2");
    s3 = seq3::type_id::create("seq3");
    s4 = seq4::type_id::create("seq4");
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    s1.start(e.a.seqr);
    #20;
    s2.start(e.a.seqr);
    #20;
    s3.start(e.a.seqr);
    #20;
    s4.start(e.a.seqr);
    phase.drop_objection(this);
  endtask
endclass

////////////////////////////////////////////////////////////////////////////////

module tb;
  spi_if sif();
  
  top dut(.clk(sif.clk), .rst(sif.rst), .din(sif.data_in), .addr(sif.addr_in), .done(sif.done), .err(sif.err), .dout(sif.data_out), .wr(sif.wr));
  
  initial begin
    sif.clk = 1'b0;
  end
  
  always #10 sif.clk = ~sif.clk;
  
  initial begin
    uvm_config_db #(virtual spi_if)::set(null,"*","sif",sif);
    run_test("test");
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
endmodule