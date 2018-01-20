`timescale 1ns / 1ns // `timescale time_unit/time_precision

module SmartLot (SW, CLOCK_50, HEX0, HEX1, VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_R, VGA_G, VGA_B,
					  GPIO_0, GPIO_1);
	input	CLOCK_50;
	input [9:0] SW;
	
	input wire [35:0] GPIO_0;
	assign echo = GPIO_0[0];
	
	output wire [35:0] GPIO_1;
	assign GPIO_1[0] = trigger;
	
	output [0:6] HEX0;
	output [0:6] HEX1;
	output	VGA_CLK;
	output	VGA_HS;
	output	VGA_VS;
	output	VGA_BLANK_N;
	output	VGA_SYNC_N;
	output	[9:0]	VGA_R;
	output	[9:0]	VGA_G;
	output	[9:0]	VGA_B;
	
	wire resetn;
	assign resetn = SW[8];

	wire [2:0] colouroriginal;
	wire [2:0] colourfinal;
	
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;
	wire [14:0] AddressOriginal;
	wire [14:0] AddressFinal;
	wire background;
	
	wire [3:0] cState;
	wire [3:0] nState;
	
	wire resetCFinaln;
	wire resetCOriginaln;
	
	wire originalEn;
	wire finalEn;
	
	wire flag;
	wire [11:0] distance;
	wire [23:0] period_cnt_output;
	
	
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(background? colourfinal: colouroriginal),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "SmartLot_bckgrn.mif";
			
	//RAMORIGINAL
	background_original bo1	(
		.address(AddressOriginal),
		.clock(CLOCK_50),
		.data(3'b111),
		.wren(1'b0),
		.q(colouroriginal[2:0]));
		
		
	//RAMFINAL
	SmartLot_bckgrn_two sbt1 (
		.address(AddressFinal),
		.clock(CLOCK_50),
		.data(3'b111),
		.wren(1'b0),
		.q(colourfinal[2:0]));
		
	control C0 (.clk(CLOCK_50), 
				.resetn(resetn), 
				.echo(echo), 
				.fullCountFinal(AddressFinal), 
				.fullCountOriginal(AddressOriginal), 
				.resetCounterFinalN(resetCFinaln), 		
				.resetCounterOriginalN(resetCOriginaln),
				.counterEnOriginal(originalEn),
				.counterEnFinal(finalEn),
				.plot(writeEn),
				.background(background),
				.current_state(cState), 
				.next_state(nState));
		
	datapath D0 (.clk(CLOCK_50), 
				.resetn(resetn), 
				.counterEnOriginal(originalEn), 
				.counterEnFinal(finalEn), 
				.resetCounterOriginalN(resetCOriginaln), 
				.resetCounterFinalN(resetCFinaln), 
				.x(x), 
				.y(y),
				.AddressOriginal(AddressOriginal),
				.AddressFinal(AddressFinal));
		
		
		
	ranging_module rm1(
	.clk(CLOCK_50),
	.echo(echo),
	.reset(resetn),
	.trig(trigger),
	.flag(flag),
	.distance(distance),
	.period_cnt_output(period_cnt_output)
);
	
	seg7 C({1'b0,cState[2:0]},HEX0[0:6]);
	seg7 N({1'b0,nState[2:0]},HEX1[0:6]);	
		
endmodule
		
		

module control (clk, resetn, echo, fullCountFinal, fullCountOriginal, resetCounterFinalN, 
						resetCounterOriginalN, counterEnOriginal, counterEnFinal, plot, background, 
						current_state, next_state);
	input clk;
	input resetn;
	input echo;
	input [14:0] fullCountFinal;
	input [14:0] fullCountOriginal;
	
	output reg resetCounterFinalN;
	output reg resetCounterOriginalN;
	output reg counterEnOriginal;
	output reg counterEnFinal;
	output reg plot;
	output reg background;
	
	output reg [3:0] current_state;
	output reg [3:0] next_state;

	localparam 
		START	 				= 4'd0,
		READ_FINAL			= 4'd1,
		WRITE_FINAL			= 4'd2,
		FINAL_COUNT			= 4'd3,
		FINAL_WAIT			= 4'd4,
		READ_ORIGINAL		= 4'd5,
		WRITE_ORIGINAL		= 4'd6,
		ORIGINAL_COUNT		= 4'd7;
		
	always @(*)
	begin: state_table
		case (current_state)
			START: next_state = echo? READ_FINAL : START;
			READ_FINAL: next_state = WRITE_FINAL;
			WRITE_FINAL: next_state = (fullCountFinal[14:0] == 15'd19200) ? FINAL_WAIT : FINAL_COUNT;
			FINAL_COUNT: next_state = echo ? READ_FINAL : READ_ORIGINAL;
			FINAL_WAIT: next_state = echo ? FINAL_WAIT : READ_ORIGINAL;
			READ_ORIGINAL: next_state = WRITE_ORIGINAL;
			WRITE_ORIGINAL: next_state = (fullCountOriginal[14:0] == 15'd19200) ? START : ORIGINAL_COUNT;
			ORIGINAL_COUNT: next_state = echo ? READ_FINAL : READ_ORIGINAL;
			default: next_state = START;
		endcase
	end // state table
	
	//Output logic, datapath control signals
	always @(*)
	begin: enable_signals
		// by default make all of them 0

		counterEnOriginal = 1'b0;
		counterEnFinal = 1'b0;
		plot = 1'b0;
		background = 1'b0;
		resetCounterFinalN = 1'b1;
		resetCounterOriginalN = 1'b1;
		
		case (current_state) 
			START: begin
				resetCounterOriginalN = 1'b0;
				resetCounterFinalN = 1'b0;	
			end
			READ_FINAL: begin
			  background = 1'b1;
			end
			WRITE_FINAL: begin
			  background = 1'b1;
			  plot = 1'b1;
			end
			FINAL_COUNT: begin
			  background = 1'b1;
			  counterEnFinal = 1'b1;
			end
			FINAL_WAIT: begin
			  background = 1'b1;
			  resetCounterFinalN = 1'b0;
			end
			READ_ORIGINAL: begin
			  //background is by default 0
			end
			WRITE_ORIGINAL: begin
			  plot = 1'b1;
			end
			ORIGINAL_COUNT: begin
			  counterEnOriginal = 1'b1;
			end  			
		endcase
	end //enable signals

	//current_state registers
	always @(posedge clk)
	begin: state_FFs
		if (!resetn)
			current_state <= START;
		else 
			current_state <= next_state;
	end // state_FFs
	
	
endmodule	
	
module datapath (clk, resetn, counterEnOriginal, counterEnFinal, resetCounterOriginalN, resetCounterFinalN, x, y, AddressOriginal, AddressFinal);
	input clk;
	input resetn;
	input counterEnOriginal;
	input counterEnFinal;
	input resetCounterOriginalN;
	input resetCounterFinalN;
	
	output reg [7:0] x;
	output reg [6:0] y;

	output [14:0] AddressOriginal;
	output [14:0] AddressFinal;
	
	wire [14:0] XYcountORIG;
	wire [14:0] XYcountFINAL;

	counter_14bit_address countOriginal   (.Enable(counterEnOriginal),
														.resetn(resetCounterOriginalN),
														.clk(clk),
														.count(AddressOriginal));
			
	counter_14bit_address countFinal   	(.Enable(counterEnFinal),
													 .resetn(resetCounterFinalN),
													 .clk(clk),
													 .count(AddressFinal));
													 
	counter_14bit_coordinate	xANDyORIG  (.Enable(counterEnOriginal),
														.resetn(resetCounterOriginalN),
														.clk(clk),
														.count(XYcountORIG));	
	
	counter_14bit_coordinate	xANDyFINAL  (.Enable(counterEnFinal),
														 .resetn(resetCounterFinalN),
														 .clk(clk),
														 .count(XYcountFINAL));	


	always @(*) begin
		if (!resetn) begin
		   x = 8'd0;
		   y = 7'd0;
		end
		else begin
		   if (!resetCounterOriginalN || !resetCounterFinalN) begin
				x[7:0] = 8'd0;
				y[6:0] = 7'd0;
		   end
		   else if (counterEnOriginal) begin
				x = XYcountORIG[7:0];
				y = XYcountORIG[14:8];
		   end
			else if (counterEnFinal) begin
				x = XYcountFINAL[7:0];
				y = XYcountFINAL[14:8];
		   end
		end
	end
	
endmodule	
	
module counter_14bit_address (Enable, resetn, clk, count);
	input Enable;
	input clk;
	input resetn;
	output reg [14:0] count;

	always @ (posedge clk) begin
	   if (resetn == 1'b0) 
			count <= 15'd0;
	   
	   if (Enable) begin
			if (count[14:0] == 15'd19200) 
				count <= 15'd0;
			else
				count <= count + 1'b1;
		end
	end
endmodule

module counter_14bit_coordinate (Enable, resetn, clk, count);
	input Enable;
	input clk;
	input resetn;
	output reg [14:0] count;

	always @ (posedge clk) begin
	   if (resetn == 1'b0) 
			count <= 15'd0;
	   
	   if (Enable) begin
			if (count[14:8] == 7'd119) 
				count <= 15'd0;
			else if (count[7:0] == 8'd159) begin
				count[7:0] <= 8'd0;
				count[14:8] = count[14:8] + 1'b1;
			end
			else
				count[7:0] <= count[7:0] + 1'b1;
		end // if statement
	end // always block
endmodule


module seg7(c,led);
	input [3:0] c;
	output reg [0:6] led;
	
	always@(*) begin 
		case (c)
			0: led= 7'b0000001;
			1: led= 7'b1001111;
			2: led= 7'b0010010;
			3: led= 7'b0000110;
			4: led= 7'b1001100;
			5: led= 7'b0100100;
			6: led= 7'b0100000;
			7: led= 7'b0001111;
			8: led= 7'b0000000;
			9: led= 7'b0000100;
			10: led= 7'b0001000;	
			11: led= 7'b1100000;
			12: led= 7'b0110001;
			13: led= 7'b1000010;
			14: led= 7'b0110000;
			15: led= 7'b0111000;
			default: led=7'bx;
		endcase
	end
endmodule 	