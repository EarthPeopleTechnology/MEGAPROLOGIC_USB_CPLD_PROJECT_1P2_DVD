//#######################################################################
//#
//#	Copyright 	Earth People Technology Inc. 2012
//#
//#
//# File Name:  EPT_570_AP_M4_Top.v
//# Author:     R. Jolly
//# Date:       March 3, 2013
//# Revision:   A
//#
//# Development: USB Test Tool Interface board 
//# Application: Altera MAX II CPLD
//# Description: This file contains verilog code which will allow access
//#              to an eight bit bus in the FPGA. The FPGA receives its commands via
//#				 USB.
//#               
//#              
//#
//#************************************************************************
//#
//# Revision History:	
//#			DATE		VERSION		DETAILS		
//#			3/4/13 	    A			Created			
//#                     			
//#
//#									
//#
//#######################################################################

`timescale 1ns/1ps



//************************************************************************
//* Module Declaration
//************************************************************************

module EPT_570_AP_M4_Top (

	
	input  wire [1:0]          aa,
	input  wire [1:0]          bc_in,
	output wire [2:0]          bc_out,
	inout  wire [7:0]		   bd_inout,
	
	output wire  [7:0]         LB_BYTE_A,       //XIOL -- J3
	output wire  [7:0]         LB_BYTE_B,       //XIOH1 -- J3
	output wire  [7:0]         LB_BYTE_C,       //XIOH2 -- J3
	output wire  [7:0]         LB_BYTE_D,       //COMMS -- J5
	
	
	//Transceiver Control Signals
	output wire                TR_DIR_1,
	output wire                TR_OE_1,
	
	output wire                TR_DIR_2,
	output wire                TR_OE_2,

	output wire                TR_DIR_3,
	output wire                TR_OE_3,

	output wire                TR_DIR_4,
	output wire                TR_OE_4,

	input wire                 SW_USER_1,
	input wire                 SW_USER_2,

	output reg [3:0]           LED
	);

   //-----------------------------------------------
   // Parameters
   //-----------------------------------------------

   //Header Bytes for the Transfer Loopback detection
   parameter                   TRANSFER_CONTROL_BYTE1 = 8'h5A;
   parameter                   TRANSFER_CONTROL_BYTE2 = 8'hC3;
   parameter                   TRANSFER_CONTROL_BYTE3 = 8'h7E;
   
   //State Machine Transfer Loopback detection
   parameter                   TRANSFER_CONTROL_IDLE = 0,
			                   TRANSFER_CONTROL_HDR1 = 1,
			                   TRANSFER_CONTROL_HDR2 = 2,
			                   TRANSFER_DECODE_BYTE   = 3,
			                   TRANSFER_CONTROL_SET  = 4;

   parameter                   GLOBAL_RESET_COUNT = 10'h03c8;
   
   //Transfer to Host State Machine
   parameter                   TRANSFER_HOST_IDLE = 1,
                               TRANSFER_HOST_LOOPBACK_START = 2,
							   TRANSFER_HOST_LOOPBACK_COMPLETE = 3;

	//Block Transfer to Host State Machine
   parameter                   BLOCK_LOOPBACK_IDLE = 1,
                               BLOCK_LOOPBACK_INIT = 2,
							   FIFO_EN_HIGH = 3,
							   FIFO_EN_LOW = 4;

	//Block Transfer to Host Counter
   parameter                   BLK_TRANSFER_OUT_IDLE = 1,
			                   BLK_TRANSFER_OUT_COUNT = 2;
							   
//***************************************************************************
//* Internal Signals and Registers Declarations
//***************************************************************************
    wire                       CLK_66;
	wire                       RST;

	wire [23:0]                UC_IN;
	wire [21:0]                UC_OUT;
	
	//Trigger Signals
	reg [7:0]                  trigger_out;
	wire [7:0]                 trigger_in_byte;	
	reg [7:0]                  trigger_in_store;
	
	//LED registers
	reg                        led_reset;
	
	//Switch registers
	reg                        switch_reset;
	
	//Transfer registers
	reg                        transfer_out_reg;
	wire                       transfer_in_received;
	wire [7:0]                 transfer_in_byte;
	reg  [7:0]                 transfer_out_byte;
	reg  [3:0]                 transfer_to_host_counter;
	reg  [3:0]                 transfer_to_host_state;

    //Transfer Control registers
	reg                        transfer_in_loop_back;
	reg                        transfer_in_received_reg;
	reg  [3:0]                 transfer_control_state;
	reg  [7:0]                 transfer_control_byte;
	
	//Block Transfer Out registers
	reg [2:0]                  state_block_loopback;
	reg                        block_out_reg;
	wire                       block_out_received;
	reg [7:0]                  block_out_counter;
	reg                        start_block_transfer;
	reg                        start_block_transfer_reg;
	wire                       block_byte_ready;
	wire [7:0]                 block_out_byte;
	reg [1:0]                  block_transfer_out_state;
	
	//Block Transfer In registers
	wire [7:0]                 block_in_data;
	wire                       block_in_rcv;
	reg                        block_in_loopback;
	wire  [7:0]                ept_length;
	wire                       block_busy;

	//Block Transfer In FIFO registers
	reg                        fifo_rden;
	reg                        fifo_rden_reg;
	reg                        fifo_wren;
	reg                        fifo_wren_reg;
	wire [7:0]                 fifo_dout;
	wire                       fifo_empty;
	wire                       fifo_aempty;
	wire                       fifo_full;
	wire                       fifo_afull;


	//Reset signals
	wire                       reset;
	reg [9:0]                 reset_counter;
	reg                        reset_signal_reg;
	

//***************************************************************************
//* 	Signal Assignments	
//***************************************************************************
   assign            LB_BYTE_A[7:0] = 8'h0;
   assign            LB_BYTE_B[7:0] = 8'h0;         
   assign            LB_BYTE_C[7:0] = 8'h0;
   assign            LB_BYTE_D[7:0] = 8'h0;
   
   assign            TR_DIR_1  = 1'b0; //1 = A to B; 0 = B to A
   assign            TR_OE_1  = 1'b1;
   assign            TR_DIR_2  = 1'b0; //1 = A to B; 0 = B to A
   assign            TR_OE_2  = 1'b1;
   assign            TR_DIR_3  = 1'b0; //1 = A to B; 0 = B to A
   assign            TR_OE_3  = 1'b1;  
   assign            TR_DIR_4  = 1'b0; //1 = A to B; 0 = B to A
   assign            TR_OE_4  = 1'b1;  

   //Clock and Reset
   assign            CLK_66 = aa[1];
   assign            RST = reset;
   assign            reset = reset_signal_reg;
    
   //Block In Transfer
   assign            block_out_byte = block_in_loopback ? fifo_dout : block_out_counter[7:0];
    
   
//**************************************************
//* 	Reset Signal	
//**************************************************
	always @(posedge CLK_66 or negedge aa[0])
	begin
	  if(!aa[0])
	  begin
			reset_signal_reg <= 1'b0;
			reset_counter <= 0;
	  end
	  else
	  begin
		if( reset_counter < GLOBAL_RESET_COUNT )
		begin
			reset_signal_reg <= 1'b0;
			reset_counter <= reset_counter + 1'b1;
		end
		else
		begin
			reset_signal_reg <= 1'b1;
		end
	  end
	end

   //-----------------------------------------------
   // LED Set
   //-----------------------------------------------

  always @(trigger_in_byte or led_reset or LED or RST)
  begin
     if(!RST)
	     LED = 4'hz;
	else if(led_reset)
	     LED = 4'hz;
	else if(trigger_in_byte[3:0])
	 begin
	     case(trigger_in_byte[3:0])
		     4'h1:
	             LED[0] = 1'b0;
		     4'h2:
	             LED[1] = 1'b0;
		     4'h4:
	             LED[2] = 1'b0;
		     4'h8:
	             LED[3] = 1'b0;
			 default:
	             LED = LED;
		 endcase
	 end
  
  end

   //-----------------------------------------------
   // User Switch Trigger
   //-----------------------------------------------
  always @(posedge CLK_66 or negedge RST)
  begin
     if(!RST)
	 begin
	     trigger_out <= 8'h00;
	 end
	else 
	begin
	   if(!SW_USER_1 )
	        trigger_out <= 8'h01;
	   else if(!SW_USER_2 )
	        trigger_out <= 8'h02;
	    else if(switch_reset)
	        trigger_out <= 8'h04;
	    else 
	        trigger_out <= 8'h00;
	end
  end

   //-----------------------------------------------
   // Set Loop Back for Transfer In
   //-----------------------------------------------
    always @(posedge CLK_66 or negedge RST) 
	begin
	     if (!RST)
		 begin
			 transfer_in_received_reg <= 1'b0;
			 transfer_control_state <= TRANSFER_CONTROL_IDLE;

			 transfer_in_loop_back <= 1'b0;
			 block_in_loopback <= 1'b0;
			 led_reset <= 1'b0;
			 switch_reset <= 1'b0;
		 end 
		 else 
		 begin 
		     if(transfer_in_received & !transfer_in_received_reg)
			 begin
			     transfer_in_received_reg <= 1'b1;
		         case(transfer_control_state)
			     TRANSFER_CONTROL_IDLE:
		             if((transfer_in_byte == TRANSFER_CONTROL_BYTE1))
			             transfer_control_state <= TRANSFER_CONTROL_HDR1;
				     else if((transfer_in_byte != TRANSFER_CONTROL_BYTE1))
			             transfer_control_state <= TRANSFER_CONTROL_IDLE;
				     else
				         transfer_control_state <= TRANSFER_CONTROL_IDLE;
			     TRANSFER_CONTROL_HDR1:
		             if((transfer_in_byte == TRANSFER_CONTROL_BYTE2))
			             transfer_control_state <= TRANSFER_CONTROL_HDR2;
				     else if((transfer_in_byte != TRANSFER_CONTROL_BYTE2))
			             transfer_control_state <= TRANSFER_CONTROL_IDLE;
				     else
				         transfer_control_state <= TRANSFER_CONTROL_HDR1;
			     TRANSFER_CONTROL_HDR2:
		             if((transfer_in_byte == TRANSFER_CONTROL_BYTE3))
			             transfer_control_state <= TRANSFER_DECODE_BYTE;
				     else if((transfer_in_byte != TRANSFER_CONTROL_BYTE3))
			             transfer_control_state <= TRANSFER_CONTROL_IDLE;
				     else
				         transfer_control_state <= TRANSFER_CONTROL_HDR2;
			     TRANSFER_DECODE_BYTE:
			     begin
   				     transfer_in_loop_back <= transfer_in_byte[0];
					 block_in_loopback <= transfer_in_byte[1];
					 led_reset <= transfer_in_byte[2];
					 switch_reset <= transfer_in_byte[3];
			         transfer_control_state <= TRANSFER_CONTROL_SET;
				 end
			     TRANSFER_CONTROL_SET:
			     begin
			         transfer_control_state <= TRANSFER_CONTROL_IDLE;
				 end
			     endcase
			 end
			 else if(!transfer_in_received & transfer_in_received_reg)
			     transfer_in_received_reg <= 1'b0;
         end
	end	 
	
   //-----------------------------------------------
   // Transfer to Host in Loop Back Mode 
   //-----------------------------------------------
    always @(posedge CLK_66 or negedge reset) 
	begin
	     if (!reset)
		 begin
			 transfer_out_reg <= 1'b0;
			 transfer_to_host_counter <= 0;
			 transfer_to_host_state <= TRANSFER_HOST_IDLE;
	     end 
		 else 
		 begin
			     transfer_out_reg <= 1'b0;
			case(transfer_to_host_state)
             TRANSFER_HOST_IDLE:
			     if(transfer_in_received & transfer_in_loop_back)	
                 begin			 
			         transfer_out_byte = transfer_in_byte;
			         transfer_to_host_state <= TRANSFER_HOST_LOOPBACK_START;
			     end
             TRANSFER_HOST_LOOPBACK_START:
		         if(transfer_to_host_counter < 4'hf)
			     begin
		             transfer_to_host_counter <= transfer_to_host_counter + 1'd1;
			         transfer_to_host_state <= TRANSFER_HOST_LOOPBACK_START;
			     end
				 else
				 begin
			         transfer_out_reg <= 1'b1;
			         transfer_to_host_state <= TRANSFER_HOST_LOOPBACK_COMPLETE;				 
				 end
             TRANSFER_HOST_LOOPBACK_COMPLETE:
			     begin
			         transfer_out_reg <= 1'b0;
					 transfer_to_host_counter <= 0;
			         transfer_to_host_state <= TRANSFER_HOST_IDLE;
				 end
			 default:
			      begin
			          transfer_out_reg <= 1'b0;
			          transfer_to_host_counter <= 0;
			          transfer_to_host_state <= TRANSFER_HOST_IDLE;
				  end
			 endcase
	     end
    end

   //-----------------------------------------------
   // Detect Block Transfer Out start
   //-----------------------------------------------
  always @(block_out_reg or trigger_in_byte or RST)
  begin
     if(!RST)
	     start_block_transfer = 1'b0;
	 else if(block_out_reg)
	     start_block_transfer = 1'b0;
	 else if((trigger_in_byte[7]))
	     start_block_transfer = 1'b1;
  
  end
  
   //-----------------------------------------------
   // Registers to start Block Transfer Out
   //-----------------------------------------------
  always @(posedge CLK_66 or negedge RST)
  begin
    if(!RST)
	begin
		 block_out_reg <= 1'b0;
		 start_block_transfer_reg <= 1'b0;
		 block_out_counter <= 0;
		 block_transfer_out_state <= BLK_TRANSFER_OUT_IDLE;
	end
	else
	begin
	     case(block_transfer_out_state)
		     BLK_TRANSFER_OUT_IDLE:
	             if(start_block_transfer )
				 begin
		             start_block_transfer_reg <= 1'b1;
		             block_transfer_out_state <= BLK_TRANSFER_OUT_COUNT;
				 end
			 BLK_TRANSFER_OUT_COUNT:
		         begin
			          block_out_reg <= 1'b1;
	                 if(block_byte_ready)
		             begin
		                 block_out_counter <= block_out_counter + 1'd1;
		             end
		             else if(block_out_counter >= ept_length )
		             begin
		                 block_out_counter <= 0;
			             block_out_reg <= 1'b0;
		                 block_transfer_out_state <= BLK_TRANSFER_OUT_IDLE;
		             end
				 end
			 default:
			      begin
		                 block_out_counter <= 0;
			             block_out_reg <= 1'b0;
		                 block_transfer_out_state <= BLK_TRANSFER_OUT_IDLE;
				  end
			 endcase
	end
  end

   //-----------------------------------------------
   // Block In write fifo enable is driven by block_byte_ready
   //-----------------------------------------------
  always @(posedge CLK_66 or negedge RST)
  begin
    if(!RST)
	begin
		 fifo_wren <= 1'b0;
		 fifo_wren_reg <= 1'b0;
	end
	else 
	begin
	     if(block_in_rcv & block_byte_ready & !fifo_wren_reg)
		 begin
		     fifo_wren <= 1'b1;
		     fifo_wren_reg <= 1'b1;
		 end
	     else if(block_in_rcv & block_byte_ready & fifo_wren_reg)
		 begin
		     fifo_wren <= 1'b0;
		     fifo_wren_reg <= 1'b1;
		 end
	     else if(block_in_rcv & !block_byte_ready & fifo_wren_reg)
		 begin
		     fifo_wren <= 1'b0;
		     fifo_wren_reg <= 1'b0;
		 end
	end 
  end
   
   //-----------------------------------------------
   // Block In read fifo enable is driven by block_byte_ready
   //-----------------------------------------------
  always @(posedge CLK_66 or negedge RST)
  begin
    if(!RST)
	begin
		 fifo_rden <= 1'b0;
		state_block_loopback <= BLOCK_LOOPBACK_IDLE;
	end
	else 
	begin
	     if(block_in_loopback) 
		 begin
		     case(state_block_loopback)
			 BLOCK_LOOPBACK_IDLE:
			 begin
		         fifo_rden <= 1'b0;
			     if(block_out_reg)
				    state_block_loopback <= BLOCK_LOOPBACK_INIT;
			 end
			 BLOCK_LOOPBACK_INIT:
			 begin
		         fifo_rden <= 1'b1;
				 state_block_loopback <= FIFO_EN_HIGH;
		     end
			 FIFO_EN_HIGH:
		     begin
	             if(block_byte_ready )
				 begin
		             fifo_rden <= 1'b1;
				     state_block_loopback <= FIFO_EN_LOW;
				 end
				 else
				 begin
		             fifo_rden <= 1'b0;
				     state_block_loopback <= FIFO_EN_HIGH;
				 end
		     end
			 FIFO_EN_LOW:
		     begin
				 if(block_out_counter == 0)
				 begin
		             fifo_rden <= 1'b0;
					 if(block_out_reg)
				         state_block_loopback <= BLOCK_LOOPBACK_IDLE;
				 end
	             else if(!block_byte_ready )
				 begin
		             fifo_rden <= 1'b0;
				     state_block_loopback <= FIFO_EN_HIGH;
				 end
			 end
			 endcase
		 end
		 else
		 begin
		     fifo_rden <= 1'b0;
		     state_block_loopback <= BLOCK_LOOPBACK_IDLE;
		 end
	end 
  end

  //-----------------------------------------------
   // Block In Sync FIFO stores bytes from the Host
   //-----------------------------------------------
  sync_fifo #(
      .ADDR_WIDTH               (4),
	  .DATA_WIDTH               (8),
	  .DEPTH                    (16),
	  .AEMPTY                   (2),
	  .AFULL                    (7)
	  ) BLOCK_IN_FIFO
     (
	  .clk                     (CLK_66),
	  .reset_n                 (RST),
	  .flush                   (1'b0),
	  .write_data              (block_in_data),	  
	  .read_req                (fifo_rden),
	  .wdata_valid             (fifo_wren),
	  .read_data               (fifo_dout),
	  .rdata_valid             (),
	  .fifo_empty              (fifo_empty),
	  .fifo_aempty             (fifo_aempty),
	  .fifo_full               (fifo_full),
	  .fifo_afull              (fifo_afull),
	  .write_ack               ()
      );


   //-----------------------------------------------
   // Instantiate the EPT Library
   //-----------------------------------------------

	active_transfer_library	   ACTIVE_TRANSFER_LIBRARY_INST
	(	
	.aa                        (aa),
	.bc_in                     (bc_in),
	.bc_out                    (bc_out),
	.bd_inout                  (bd_inout),

	.UC_IN                     (UC_IN),
	.UC_OUT                    (UC_OUT)
	
	);
	
   //-----------------------------------------------
   // Instantiate the EPT Library
   //-----------------------------------------------
wire [22*3-1:0]  uc_out_m;
eptWireOR # (.N(3)) wireOR (UC_OUT, uc_out_m);
	active_trigger             ACTIVE_TRIGGER_INST
	(
	 .uc_clk                   (CLK_66),
	 .uc_reset                 (RST),
	 .uc_in                    (UC_IN),
	 .uc_out                   (uc_out_m[ 0*22 +: 22 ]),

	 .trigger_to_host          (trigger_out),
	 .trigger_to_device        (trigger_in_byte)
	
	);

	active_transfer            ACTIVE_TRANSFER_INST
	(
	 .uc_clk                   (CLK_66),
	 .uc_reset                 (RST),
	 .uc_in                    (UC_IN),
	 .uc_out                   (uc_out_m[ 1*22 +: 22 ]),
	
	 .start_transfer           (transfer_out_reg),
	 .transfer_received        (transfer_in_received),
	
	 .uc_addr                  (3'h2),

	 .transfer_to_host         (transfer_out_byte),
	 .transfer_to_device       (transfer_in_byte)	
	);
	
	active_block               BLOCK_TRANSFER_INST
	(
	 .uc_clk                   (CLK_66),
	 .uc_reset                 (RST),
	 .uc_in                    (UC_IN),
	 .uc_out                   (uc_out_m[ 2*22 +: 22 ]),
	
	 .start_transfer           (block_out_reg),
	 .transfer_received        (block_in_rcv),
	 
	 .transfer_ready           (block_byte_ready),
	 .transfer_busy            (block_busy),

	 .ept_length               (ept_length),
	
	 .uc_addr                  (3'h4),
	 .uc_length                (ept_length),

	 .transfer_to_host         (block_out_byte),
	 .transfer_to_device       (block_in_data)
	
	);

	
endmodule
