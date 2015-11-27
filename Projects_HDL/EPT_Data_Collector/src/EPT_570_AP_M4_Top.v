//#######################################################################
//#
//#	Copyright 	Earth People Technology Inc. 2013
//#
//#
//# File Name:  EPT_570_AP_M4_Top.v
//# Author:     Earth People Technology
//# Date:       March 9, 2013
//# Revision:   A
//#
//# Development: EPT Data Collection Project 
//# Application: Altera MAX II CPLD
//# Description: This file contains verilog code which will allow access
//#              to Active Transfer Library. 
//#               
//#              
//#
//#************************************************************************
//#
//# Revision History:	
//#			DATE		VERSION		DETAILS		
//#			3/9/13 	1			Created
//#                                 
//#
//#									
//#
//#######################################################################


//************************************************************************
//* Module Declaration
//************************************************************************

module EPT_570_AP_M4_Top (

	
	input  wire [1:0]          aa,
	input  wire [1:0]          bc_in,
	output wire [2:0]          bc_out,
	inout  wire [7:0]		   bd_inout,
	
	output wire  [7:0]         LB_BYTE_A,       //XIOL -- J3
	input wire   [7:0]         LB_BYTE_B,       //XIOH1 -- J3
	input wire   [7:0]         LB_BYTE_C,       //XIOH2 -- J3
	output reg   [7:0]         LB_BYTE_D,       //COMMS -- J5
	
	
	//Transceiver Control Signals
	output wire                TR_DIR_1,
	output wire                TR_OE_1,
	
	output wire                TR_DIR_2,
	output wire                TR_OE_2,

	output wire                TR_DIR_3,
	output wire                TR_OE_3,

	output reg                 TR_DIR_4,
	output reg                 TR_OE_4,
	
	input wire                 SW_USER_1,
	input wire                 SW_USER_2,

	output reg [2:0]           LED,
	output wire                LED3
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

   parameter                   GLOBAL_RESET_COUNT = 12'h09c8;
   
 	
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
	wire                       transfer_out;
	reg                        transfer_out_reg;
	wire                       transfer_in_received;
	wire [7:0]                 transfer_in_byte;
	wire  [7:0]                transfer_out_byte;
	reg  [3:0]                 transfer_to_host_counter;
	reg  [3:0]                 transfer_to_host_state;

    //Transfer Control registers
	reg                        transfer_in_loop_back;
	reg                        transfer_in_received_reg;
	reg  [3:0]                 transfer_control_state;
	reg  [7:0]                 transfer_control_byte;
	
    //Transfer Write from Arduino
	reg                        transfer_write_reg;
	reg                        transfer_write;
	reg  [7:0]                 transfer_write_byte;

	//Reset signals
	wire                       reset;
	reg [11:0]                 reset_counter;
	reg                        reset_signal_reg;
	
	//Input/Output Signals
	reg                        start_stop_cntrl;


//***************************************************************************
//* 	Signal Assignments	
//***************************************************************************
   assign            LB_BYTE_A[7:0] = 8'h0;         

   assign            TR_DIR_1  = 1'b1; //1 = A to B; 0 = B to A
   assign            TR_OE_1  = 1'b1;

   assign            TR_DIR_2  = 1'b1; //1 = A to B; 0 = B to A
   assign            TR_OE_2  = 1'b0;

   assign            TR_DIR_3  = 1'b1; //1 = A to B; 0 = B to A
   assign            TR_OE_3  = 1'b0;  

   //Clock and Reset
   assign            CLK_66 = aa[1];
   assign            RST = reset;
   assign            reset = reset_signal_reg;
   
   //Transfer registers
   assign            transfer_out = transfer_out_reg | transfer_write;
   assign            transfer_out_byte = transfer_write_byte;
   
   //LED3 is used to signify to the  user that the Start 
   //switch is enabled
   assign             LED3 =  start_stop_cntrl ? 1'b0 : 1'bz;  
     
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
	     LED[2:0] = 3'hz;
	else if(led_reset)
	     LED[2:0] = 3'hz;
	else if(trigger_in_byte[3:0])
	 begin
	     case(trigger_in_byte[3:0])
		     3'h1:
	             LED[0] = 1'b0;
		     3'h2:
	             LED[1] = 1'b0;
		     3'h4:
	             LED[2] = 1'b0;
			 default:
	             LED[2:0] = LED[2:0];
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
   // Detect Transfer From Arduino
   //-----------------------------------------------
    always @(posedge CLK_66 or negedge RST) 
	begin
       if (!RST)
       begin
			transfer_write_reg <= 1'b0;
			transfer_write <= 1'b0;
			transfer_write_byte <= 0;
            TR_DIR_4  <= 1'b0; //1 = A to B; 0 = B to A
            TR_OE_4  <= 1'b0;
            LB_BYTE_D[0] <= start_stop_cntrl;
            LB_BYTE_D[7:1] <= 7'b0000000;    
       end 
       else 
       begin 
	        if(LB_BYTE_B[0] & !transfer_write_reg)
			begin
                 TR_OE_4  <= 1'b1;
                 LB_BYTE_D <= 8'hz;
			    transfer_write_reg <= 1'b1;
				transfer_write <= 1'b1;
				transfer_write_byte <= LB_BYTE_C;
			end
	        else if(LB_BYTE_B[0] & transfer_write_reg)
			begin
			    transfer_write_reg <= 1'b1;
				transfer_write <= 1'b0;
			end
	        else if(!LB_BYTE_B[0] & transfer_write_reg)
			begin
			    transfer_write_reg <= 1'b0;
				transfer_write <= 1'b0;
			    transfer_write_byte <= 0;
			end
			else
			begin
                 TR_DIR_4  <= 1'b0; //1 = A to B; 0 = B to A
                 TR_OE_4  <= 1'b0;
                 LB_BYTE_D[0] <= start_stop_cntrl;
                 LB_BYTE_D[7:1] <= 7'b0000000;    
			end
	   end
    end
   //-----------------------------------------------
   // State Machine: Control Register from Transfer In 
   //-----------------------------------------------
    always @(posedge CLK_66 or negedge RST) 
	begin
	     if (!RST)
		 begin
			 transfer_in_received_reg <= 1'b0;
			 transfer_control_state <= TRANSFER_CONTROL_IDLE;
			 transfer_in_loop_back <= 1'b0;
			 led_reset <= 1'b0;
			 switch_reset <= 1'b0;
			 start_stop_cntrl <= 1'b0;
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
					 start_stop_cntrl <= transfer_in_byte[0];
					 led_reset <= transfer_in_byte[2];
					 switch_reset <= transfer_in_byte[3];
				     transfer_in_loop_back <= transfer_in_byte[4];
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
   // Instantiate the EPT Active Transfer Library
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
   // Instantiate the EPT Active Modules
   //-----------------------------------------------
wire [22*2-1:0]  uc_out_m;
eptWireOR # (.N(2)) wireOR (UC_OUT, uc_out_m);
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
	
	 .start_transfer           (transfer_out),
	 .transfer_received        (transfer_in_received),
	
	 .uc_addr                  (3'h2),

	 .transfer_to_host         (transfer_out_byte),
	 .transfer_to_device       (transfer_in_byte)	
	);
	
	
endmodule
