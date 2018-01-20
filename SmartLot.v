`timescale 1ns / 1ns // `timescale time_unit/time_precision

module SmartLot (SW, CLOCK_50, GPIO_0, GPIO_1, HEX0, HEX1, HEX4, HEX5,  backgroundColour, AUD_ADCDAT, AUD_BCLK, AUD_ADCLRCK, AUD_DACLRCK, FPGA_I2C_SDAT, 
					  AUD_XCK, AUD_DACDAT, FPGA_I2C_SCLK, VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_R, VGA_G, VGA_B);
					  
	// General I/O signals
	input	CLOCK_50;
	input [9:0] SW;
	output [0:6] HEX0;
	output [0:6] HEX1;
	output [0:6] HEX4;
	output [0:6] HEX5;
	
	// Audio I/O signals
	input		AUD_ADCDAT;
	inout		AUD_BCLK;
	inout		AUD_ADCLRCK;
	inout		AUD_DACLRCK;
	inout		FPGA_I2C_SDAT;
	output	AUD_XCK;
	output	AUD_DACDAT;
	output	FPGA_I2C_SCLK;

	// VGA I/O signals
	output	VGA_CLK;
	output	VGA_HS;
	output	VGA_VS;
	output	VGA_BLANK_N;
	output	VGA_SYNC_N;
	output	[7:0]	VGA_R;
	output	[7:0]	VGA_G;
	output	[7:0]	VGA_B;
	
	input wire [35:0] GPIO_0;
	
	output wire [35:0] GPIO_1;
	
	wire resetn;
	assign resetn = SW[8];

	wire [2:0] colouroriginal;
	wire [2:0] colourfinal;
	wire [2:0] colourcrash;
	wire [2:0] colourblack;
	
	wire [8:0] x;
	wire [7:0] y;
	wire writeEn;
	wire [16:0] AddressOriginal;
	wire [16:0] AddressFinal;
	wire [16:0] AddressCrash;
	wire [16:0] AddressBlack;
	wire [1:0] Bselect;
	
	wire [3:0] cState;
	wire [3:0] nState;
	
	wire resetCFinaln;
	wire resetCOriginaln;
	wire resetCCrashn;
	wire resetCBlackn;
	
	wire originalEn;
	wire finalEn;
	wire crashEn;
	wire blackEn;	
	
	assign echo = GPIO_0[0]; 
 	assign GPIO_1[0] = trigger; 

	wire flag;
	wire [3:0] distance_cm;
	wire [3:0] distance_mm;
	
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(backgroundColour),
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
		defparam VGA.RESOLUTION = "320x240";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "SmartLot_bckgrn_HD.mif";
		
	output reg [2:0] backgroundColour;
	always @(posedge CLOCK_50) begin
		case(Bselect)
			2'b00: backgroundColour <= colouroriginal;
			2'b01: backgroundColour <= colourfinal;
			2'b10: backgroundColour <= colourcrash;
			2'b11: backgroundColour <= colourblack;
			default: backgroundColour <= colouroriginal;
		endcase
	end
	
	//RAMORIGINAL
	SmartLot_bckgrn_HD SBH1	(
		.address(AddressOriginal),
		.clock(CLOCK_50),
		.data(3'b111),
		.wren(1'b0),
		.q(colouroriginal[2:0]));
		
		
	//RAMFINAL
	SmartLot_bckgrn_two_HD SBTH1 (
		.address(AddressFinal),
		.clock(CLOCK_50),
		.data(3'b111),
		.wren(1'b0),
		.q(colourfinal[2:0]));
		
	//RAMCRASH
	Crash Cr0(
		.address(AddressCrash),
		.clock(CLOCK_50),
		.data(3'b111),
		.wren(1'b0),
		.q(colourcrash[2:0]));
	//RAMFINAL
	black B0(
		.address(AddressBlack),
		.clock(CLOCK_50),
		.data(3'b111),
		.wren(1'b0),
		.q(colourblack[2:0]));
		
	wire pulse;
	wire onesec;
	wire halfsec;
	wire quartersec;
	wire eighthsec;
	
	DE1_SoC_Audio Audio (.CLOCK_50(CLOCK_50),
								.reset(pulse),
								.AUD_ADCDAT(AUD_ADCDAT),
								.AUD_BCLK(AUD_BCLK),
								.AUD_ADCLRCK(AUD_ADCLRCK),
								.AUD_DACLRCK(AUD_DACLRCK),
								.FPGA_I2C_SDAT(FPGA_I2C_SDAT),
								.AUD_XCK(AUD_XCK),
								.AUD_DACDAT(AUD_DACDAT),
								.FPGA_I2C_SCLK(FPGA_I2C_SCLK),
								.SW(SW[3:0]));
					
	distance_to_soundFreq_Converter Converter(.clk(CLOCK_50),
															.resetn(resetn),
															.distance_cm(distance_cm),
															.pulse(pulse),
															.OneSecBPS(onesec), 
															.halfSecBPS(halfsec), 
															.quarterSecBPS(quartersec),
															.eighthSecBPS(eighthsec));
	
	ranging_module r0 (.clk(CLOCK_50), 
							 .echo(echo), 
							 .resetn(resetn),
							 .trig(trigger),
							 .flag(flag),
							 .distance_cm(distance_cm),
							 .distance_mm(distance_mm));	
	
	control C0 (.clk(CLOCK_50), 
				.resetn(resetn), 
				.echo(flag),
				.distance_cm(distance_cm),
				.fullCountFinal(AddressFinal), 
				.fullCountOriginal(AddressOriginal), 
				.fullCountCrash(AddressCrash),
				.fullCountBlack(AddressBlack),
				.resetCounterFinalN(resetCFinaln), 		
				.resetCounterOriginalN(resetCOriginaln),
				.resetCounterCrashN(resetCCrashn),
				.resetCounterBlackN(resetCBlackn),
				.counterEnOriginal(originalEn),
				.counterEnFinal(finalEn),
				.counterEnCrash(crashEn),
				.counterEnBlack(blackEn),
				.plot(writeEn),
				.Bselect(Bselect),
				.current_state(cState), 
				.next_state(nState));
		
	datapath D0 (.clk(CLOCK_50), 
				.resetn(resetn), 
				.counterEnOriginal(originalEn),
				.counterEnFinal(finalEn),
				.counterEnCrash(crashEn),
				.counterEnBlack(blackEn),
				.resetCounterFinalN(resetCFinaln), 		
				.resetCounterOriginalN(resetCOriginaln),
				.resetCounterCrashN(resetCCrashn),
				.resetCounterBlackN(resetCBlackn),
				.x(x), 
				.y(y),
				.AddressOriginal(AddressOriginal),
				.AddressFinal(AddressFinal),
				.AddressCrash(AddressCrash),
				.AddressBlack(AddressBlack));	
	
	seg7 CS(cState, HEX5[0:6]);
	seg7 NS(nState, HEX4[0:6]);
	
	seg7 MM(distance_mm[3:0], HEX0[0:6]);
	seg7 CM(distance_cm[3:0], HEX1[0:6]);

endmodule
		

module control (clk, resetn, echo, distance_cm, fullCountFinal, fullCountOriginal, fullCountCrash, fullCountBlack, 
					resetCounterFinalN, resetCounterOriginalN, resetCounterCrashN, resetCounterBlackN, counterEnOriginal, 
					counterEnFinal, counterEnCrash, counterEnBlack, plot, Bselect, current_state, next_state);
	input clk;
	input resetn;
	input echo;
	input [3:0] distance_cm;
	input [16:0] fullCountFinal;
	input [16:0] fullCountOriginal;
	input [16:0] fullCountCrash;
	input [16:0] fullCountBlack;
	
	output reg resetCounterFinalN;
	output reg resetCounterOriginalN;
	output reg resetCounterCrashN;
	output reg resetCounterBlackN;
	output reg counterEnOriginal;
	output reg counterEnFinal;
	output reg counterEnCrash;
	output reg counterEnBlack;
	output reg plot;
	output reg [1:0] Bselect;
	
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
		ORIGINAL_COUNT		= 4'd7,
		CRASH_READ 			= 4'd8,
		CRASH_WRITE			= 4'd9,
		CRASH_COUNT			= 4'd10,
		CRASH_WAIT 			= 4'd11,
		BLACK_READ 			= 4'd12,
		BLACK_WRITE			= 4'd13,
		BLACK_COUNT			= 4'd14,
		BLACK_WAIT 			= 4'D15;
		
		
	always @(*)
	begin: state_table
		case (current_state)
			START: begin
				if (!echo)
					next_state = START;
				else if (echo && distance_cm > 4'd4)
					next_state = READ_FINAL;
				else if (echo && distance_cm <= 4'd4)
					next_state = CRASH_READ;
			end
			READ_FINAL: next_state = WRITE_FINAL;
			WRITE_FINAL: next_state = (fullCountFinal[16:0] == 17'd76800) ? FINAL_WAIT : FINAL_COUNT;
			FINAL_COUNT: next_state = READ_FINAL;
			FINAL_WAIT: begin				
				if (!echo)
					next_state = READ_ORIGINAL;
				else if (echo && distance_cm > 4'd4)
					next_state = FINAL_WAIT;
				else if (echo && distance_cm <= 4'd4)
					next_state = CRASH_READ;
			end
			READ_ORIGINAL: next_state = WRITE_ORIGINAL;
			WRITE_ORIGINAL: next_state = (fullCountOriginal[16:0] == 17'd76800) ? START : ORIGINAL_COUNT;
			ORIGINAL_COUNT: next_state = READ_ORIGINAL;
			CRASH_READ: next_state = CRASH_WRITE;
			CRASH_WRITE: next_state = (fullCountCrash[16:0] == 17'd76800) ? CRASH_WAIT : CRASH_COUNT;
			CRASH_COUNT: next_state = CRASH_READ;
			CRASH_WAIT: next_state = CRASH_WAIT;/*begin				
				if (!echo)
					next_state = READ_ORIGINAL;
				else if (echo && distance_cm > 4'd4)
					next_state = READ_FINAL;
				else if (echo && distance_cm <= 4'd4)
					next_state = BLACK_READ;
			end*/
			BLACK_READ: next_state = BLACK_WRITE;
			BLACK_WRITE: next_state = (fullCountBlack[16:0] == 17'd76800) ? BLACK_WAIT : BLACK_COUNT;
			BLACK_COUNT: next_state = BLACK_READ;
			BLACK_WAIT: begin				
				if (!echo)
					next_state = READ_ORIGINAL;
				else if (echo && distance_cm > 4'd4)
					next_state = READ_FINAL;
				else if (echo && distance_cm <= 4'd4)
					next_state = CRASH_READ;
			end
			default: next_state = START;
		endcase
	end // state table
	
	//Output logic, datapath control signals
	always @(*)
	begin: enable_signals
	
		// by default make all of them 0
		counterEnOriginal = 1'b0;
		counterEnFinal = 1'b0;
		counterEnCrash = 1'b0;
		counterEnBlack = 1'b0;
		plot = 1'b0;
		Bselect = 2'b00;
		resetCounterFinalN = 1'b1;
		resetCounterOriginalN = 1'b1;
		resetCounterCrashN = 1'b1;
		resetCounterBlackN = 1'b1;
	
		
		case (current_state) 
			START: begin
				resetCounterOriginalN = 1'b0;
				resetCounterFinalN = 1'b0;	
				resetCounterCrashN = 1'b0;
				resetCounterBlackN = 1'b0;
			end
			READ_FINAL: begin
			  Bselect = 2'b01;
			  //resetCounterOriginalN = 1'b0;
			end
			WRITE_FINAL: begin
			  Bselect = 2'b01;
			  plot = 1'b1;
			end
			FINAL_COUNT: begin
			  Bselect = 2'b01;
			  counterEnFinal = 1'b1;
			end
			FINAL_WAIT: begin
			  Bselect = 2'b01;
			  resetCounterFinalN = 1'b0;
			end
			READ_ORIGINAL: begin
			  Bselect = 2'b00;
			end
			WRITE_ORIGINAL: begin
				Bselect = 2'b00;
			  plot = 1'b1;
			end
			ORIGINAL_COUNT: begin
				Bselect = 2'b00;
			  counterEnOriginal = 1'b1;
			end  	
			CRASH_READ: begin
				Bselect = 2'b10;
			end
			CRASH_WRITE: begin
				Bselect = 2'b10;
				plot = 1'b1;
			end
			CRASH_COUNT: begin
				counterEnCrash = 1'b1;
				Bselect = 2'b10;
			end
			CRASH_WAIT: begin
				Bselect = 2'b10;
				resetCounterCrashN = 1'b0;
			end
			BLACK_READ: begin
				Bselect = 2'b11;
			end
			BLACK_WRITE: begin
				Bselect = 2'b11;
				plot = 1'b1;
			end
			BLACK_COUNT: begin
				counterEnBlack = 1'b1;
				Bselect = 2'b11;
			end
			BLACK_WAIT: begin
				Bselect = 2'b11;
				resetCounterBlackN = 1'b0;
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
	
module datapath (clk, resetn, counterEnOriginal, counterEnFinal, counterEnCrash, counterEnBlack, resetCounterOriginalN, 
					resetCounterFinalN, resetCounterCrashN, resetCounterBlackN, x, y, AddressOriginal, AddressFinal, 
					AddressCrash, AddressBlack);
	input clk;
	input resetn;
	input counterEnOriginal;
	input counterEnFinal;
	input counterEnCrash;
	input counterEnBlack;
	input resetCounterOriginalN;
	input resetCounterFinalN;
	input resetCounterCrashN;
	input resetCounterBlackN;
	
	output reg [8:0] x;
	output reg [7:0] y;

	output [16:0] AddressOriginal;
	output [16:0] AddressFinal;
	output [16:0] AddressCrash;
	output [16:0] AddressBlack;
	
	wire [16:0] XYcountORIG;
	wire [16:0] XYcountFINAL;
	wire [16:0] XYcountCRASH;
	wire [16:0] XYcountBLACK;

	counter_14bit_address countOriginal   (.Enable(counterEnOriginal),
														.resetn(resetCounterOriginalN),
														.clk(clk),
														.count(AddressOriginal));
			
	counter_14bit_address countFinal   	(.Enable(counterEnFinal),
													 .resetn(resetCounterFinalN),
													 .clk(clk),
													 .count(AddressFinal));
											
	counter_14bit_address countCrash   	(.Enable(counterEnCrash),
													 .resetn(resetCounterCrashN),
													 .clk(clk),
													 .count(AddressCrash));
													 
	counter_14bit_address countBlack   	(.Enable(counterEnBlack),
													 .resetn(resetCounterBlackN),
													 .clk(clk),
													 .count(AddressBlack));
													 
	counter_14bit_coordinate	xANDyORIG  (.Enable(counterEnOriginal),
														.resetn(resetCounterOriginalN),
														.clk(clk),
														.count(XYcountORIG));	
	
	counter_14bit_coordinate	xANDyFINAL  (.Enable(counterEnFinal),
														 .resetn(resetCounterFinalN),
														 .clk(clk),
														 .count(XYcountFINAL));	
														 
	counter_14bit_coordinate	xANDyCRASH  (.Enable(counterEnCrash),
														 .resetn(resetCounterCRASHN),
														 .clk(clk),
														 .count(XYcountCRASH));														 

	counter_14bit_coordinate	xANDyBLACK  (.Enable(counterEnBlack),
														 .resetn(resetCounterBLACKN),
														 .clk(clk),
														 .count(XYcountBLACK));															 

	always @(posedge clk) begin 
		if (!resetn) begin
		   x <= 9'd0;
		   y <= 8'd0;
		end
		else begin
		   if (!resetCounterOriginalN || !resetCounterFinalN || !resetCounterCrashN || !resetCounterBlackN) begin
				x[8:0] <= 9'd0;
				y[7:0] <= 8'd0;
		   end
		   else if (counterEnOriginal) begin
				x <= XYcountORIG[8:0];
				y <= XYcountORIG[16:9];
		   end
			else if (counterEnFinal) begin
				x <= XYcountFINAL[8:0];
				y <= XYcountFINAL[16:9];
		   end
			else if (counterEnCrash) begin
				x <= XYcountCRASH[8:0];
				y <= XYcountCRASH[16:9];
		   end
			else if (counterEnBlack) begin
				x <= XYcountBLACK[8:0];
				y <= XYcountBLACK[16:9];
		   end
		end
	end
	
endmodule	

module ranging_module( 
 	input wire clk, 
 	input wire echo, 
 	input wire resetn, 
 
 
 	output reg trig, 
 	output wire flag, 
 	output wire [3:0] distance_cm,
	output wire [3:0] distance_mm
 ); 
 
 reg [22:0] period_cnt;
 wire period_cnt_full;

 
 always @(posedge clk) 
 		begin 
 			if (!resetn) 
 				period_cnt <= 0; 
 			else 
 				begin 
 					if (period_cnt_full) 
 						period_cnt <= 0; 
 					else 
 						period_cnt <= period_cnt + 1; 
 				end 
 		end 

 assign period_cnt_full = (period_cnt == 5000000);
 
 always @(posedge clk) 
 		begin 
 			if (!resetn) 
 				trig <= 0; 
 			else 
 				trig <= ( period_cnt > 100 && period_cnt < 5100); 
 		end 
		
		
reg [26:0] echo_length;
always @(posedge clk) begin
	if (!resetn)
		echo_length <= 27'd0;
	else if (trig)
		echo_length <= 27'd0;
	else if (echo) begin
		if (echo_length[11:0] == 12'd2900) // reached 10 mm, reset the mm count
			echo_length[11:0] <= 12'd0;
		else begin
			echo_length[11:0] <= echo_length[11:0] + 1'd1;
		end
		if (echo_length[26:12] == 15'd29000)
			echo_length[26:12] <= 15'd29000;
		else 
			echo_length[26:12] <= echo_length[26:12] + 1'd1; // increment the cm count until echo turns off
	end
	else 
		echo_length[26:0] <= echo_length[26:0];
end

	wire Enable;

	counter_Enable_delay CED(.clk(clk), 
								 .resetn(resetn),
								 .Enable(Enable));

								 
	reg[3:0] distance_temp_cm;
	always @(posedge clk) begin
		if (!resetn) 
			distance_temp_cm <= 4'd0;
		else if (Enable) begin
			if (trig)
				distance_temp_cm <= 4'd0;
			else if (echo_length[26:12] >= 15'd0 && echo_length[26:12] < 15'd2900)
				distance_temp_cm <= 4'd0;
			else if (echo_length[26:12] >= 15'd2900 && echo_length[26:12] < 15'd5800)
				distance_temp_cm <= 4'd1;
			else if (echo_length[26:12] >= 15'd5800 && echo_length[26:12] < 15'd8700)
				distance_temp_cm <= 4'd2;
			else if (echo_length[26:12] >= 15'd8700 && echo_length[26:12] < 15'd11600)
				distance_temp_cm <= 4'd3;
			else if (echo_length[26:12] >= 15'd11600 && echo_length[26:12] < 15'd14500)
				distance_temp_cm <= 4'd4;
			else if (echo_length[26:12] >= 15'd14500 && echo_length[26:12] < 15'd17400)
				distance_temp_cm <= 4'd5;
			else if (echo_length[26:12] >= 15'd17400 && echo_length[26:12] < 15'd20300)
				distance_temp_cm <= 4'd6;
			else if (echo_length[26:12] >= 15'd20300 && echo_length[26:12] < 15'd23200)
				distance_temp_cm <= 4'd7;
			else if (echo_length[26:12] >= 15'd23200 && echo_length[26:12] < 15'd26100)
				distance_temp_cm <= 4'd8;
			else if (echo_length[26:12] >= 15'd26100 && echo_length[26:12] < 15'd29000)
				distance_temp_cm <= 4'd9;
			else 
				distance_temp_cm <= 4'd10;
		end
		else 
			distance_temp_cm =  distance_temp_cm;
	end

 // MILLIMETER DISTANCE CALC
	reg [3:0] distance_temp_mm;
	always @(posedge clk) begin
		if (!resetn)
				distance_temp_mm <= 4'd0;
		else if (Enable) begin
			if (trig)
				distance_temp_mm <= 4'd0;
			else if (echo_length[11:0] >= 12'd0 && echo_length[11:0] < 12'd290)
				distance_temp_mm <= 4'd0;
			else if (echo_length[11:0] >= 12'd290 && echo_length[11:0] < 12'd580)
				distance_temp_mm <= 4'd1;
			else if (echo_length[11:0] >= 12'd580 && echo_length[11:0] < 12'd870)
				distance_temp_mm <= 4'd2;
			else if (echo_length[11:0] >= 12'd870 && echo_length[11:0] < 12'd1160)
				distance_temp_mm <= 4'd3;
			else if (echo_length[11:0] >= 12'd1160 && echo_length[11:0] < 12'd1450)
				distance_temp_mm <= 4'd4;
			else if (echo_length[11:0] >= 12'd1450 && echo_length[11:0] < 12'd1740)
				distance_temp_mm <= 4'd5;
			else if (echo_length[11:0] >= 12'd1740 && echo_length[11:0] < 12'd2030)
				distance_temp_mm <= 4'd6;
			else if (echo_length[11:0] >= 12'd2030 && echo_length[11:0] < 12'd2320)
				distance_temp_mm <= 4'd7;
			else if (echo_length[11:0] >= 12'd2320 && echo_length[11:0] < 12'd2610)
				distance_temp_mm <= 4'd8;
			else if (echo_length[11:0] >= 12'd2610 && echo_length[11:0] < 12'd2900)
				distance_temp_mm <= 4'd9;	
			else 
				distance_temp_mm <= 4'd10;
		end
		else 
			distance_temp_mm <= distance_temp_mm;
	end
	
	assign distance_cm = distance_temp_cm;
	assign distance_mm = distance_temp_mm;
	
	assign flag = (distance_temp_cm < 4'd10 && distance_temp_cm > 4'd1) ? 1'b1 : 1'b0;
		
endmodule

module distance_to_soundFreq_Converter (clk, resetn, distance_cm, pulse, OneSecBPS, halfSecBPS, quarterSecBPS, eighthSecBPS);
	input clk;
	input resetn;
	input [3:0] distance_cm;
	output reg pulse;
	
	output reg OneSecBPS;
	output reg halfSecBPS;
	output reg quarterSecBPS;
	output reg eighthSecBPS;
	
	wire pulse_ONE_BPS, pulse_HALF_BPS, pulse_QUARTER_BPS, pulse_EIGHTH_BPS;

	
	counter_OneSecBPS C1 (.clk(clk),
								 .resetn(resetn),
								 .oneSecBPSEn(OneSecBPS),
								 .highReset(pulse_ONE_BPS));
		
	counter_halfSecBPS C2 (.clk(clk),
								  .resetn(resetn),
								  .halfSecBPSEn(halfSecBPS),
								  .highReset(pulse_HALF_BPS));
								 
	counter_quarterSecBPS C3 	(.clk(clk),
										 .resetn(resetn),
										 .quarterSecBPSEn(quarterSecBPS),
										 .highReset(pulse_QUARTER_BPS));	
										 
	counter_eighthSecBPS C4 	(.clk(clk),
										 .resetn(resetn),
										 .eighthSecBPSEn(eighthSecBPS),
										 .highReset(pulse_EIGHTH_BPS));
	
	always @(*) begin
		// by default, set all to 0 to avoid latches being created
		OneSecBPS = 1'd0;
		halfSecBPS = 1'd0;
		quarterSecBPS = 1'd0;
		eighthSecBPS = 1'd0;
		
		if (!resetn) begin
			OneSecBPS = 1'd0;
			halfSecBPS = 1'd0;
			quarterSecBPS = 1'd0;
			eighthSecBPS = 1'd0;
		end
		else if (distance_cm < 4'd10 && distance_cm > 4'd7) 
			OneSecBPS = 1'd1;
		else if (distance_cm < 4'd8 && distance_cm > 4'd5)
			halfSecBPS = 1'd1;
		else if (distance_cm < 4'd6 && distance_cm > 4'd3)
			quarterSecBPS = 1'd1;
		else if (distance_cm < 4'd4 && distance_cm > 4'd1)
			eighthSecBPS = 1'd1;
		else if (distance_cm >= 4'd10 || distance_cm <= 4'd1) begin
			OneSecBPS = 1'd0;
			halfSecBPS = 1'd0;
			quarterSecBPS = 1'd0;
			eighthSecBPS = 1'd0;
		end
	end

	always @(*) begin
		// by default, make sound output 0
		pulse = 1'd1;
		if (OneSecBPS)
			pulse = pulse_ONE_BPS;
		else if (halfSecBPS)
			pulse = pulse_HALF_BPS;
		else if (quarterSecBPS)
			pulse = pulse_QUARTER_BPS;
		else if (eighthSecBPS)
			pulse = pulse_EIGHTH_BPS;
		else 
			pulse = 1'd1;
	end
		
	
	endmodule 
	
module counter_OneSecBPS (clk, resetn, oneSecBPSEn, highReset);
	input clk;
	input resetn;
	input oneSecBPSEn;
	
	output reg highReset;

	reg [29:0] count;
	always @(posedge clk) begin
		if (!resetn) begin
			count <= 30'd0;
			highReset <= 1'd1;
		end
		else if (oneSecBPSEn) begin
			count <= count + 1'd1;
			if (count <= 30'd49999999 && count >= 30'd0) 
				highReset <= 1'd1;
			else if (count > 30'd49999999 && count <= 30'd54999999) 
				highReset <= 1'd0;
			else if (count == 30'd55000000)
				count <= 30'd0;
		end
		else begin
			highReset <= 1'd1;
			count <= 30'd0;
		end
	end
	
endmodule

module counter_halfSecBPS (clk, resetn, halfSecBPSEn, highReset);
	input clk;
	input resetn;
	input halfSecBPSEn;
	
	output reg highReset;

	reg [29:0] count;
	always @(posedge clk) begin
		if (!resetn) begin
			count <= 30'd0;
			highReset <= 1'd1;
		end
		else if (halfSecBPSEn) begin
			count <= count + 1'd1;
			if (count <= 30'd24999999 && count >= 30'd0) 
				highReset <= 1'd1;
			else if (count > 30'd24999999 && count <= 30'd29999999) 
				highReset <= 1'd0;
			else if (count == 30'd30000000)
				count <= 30'd0;
		end
		else begin
			highReset <= 1'd1;
			count <= 30'd0;
		end
	end
endmodule

module counter_quarterSecBPS (clk, resetn, quarterSecBPSEn, highReset);
	input clk;
	input resetn;
	input quarterSecBPSEn;
	
	output reg highReset;

	reg [29:0] count;
	always @(posedge clk) begin
		if (!resetn) begin
			count <= 30'd0;
			highReset <= 1'd1;
		end
		else if (quarterSecBPSEn) begin
			count <= count + 1'd1;
			if (count <= 30'd12499999 && count >= 30'd0) 
				highReset <= 1'd1;
			else if (count > 30'd12499999 && count <= 30'd17499999) 
				highReset <= 1'd0;
			else if (count == 30'd17500000)
				count <= 30'd0;
		end
		else begin
			highReset <= 1'd1;
			count <= 30'd0;
		end
	end
	
endmodule

module counter_eighthSecBPS (clk, resetn, eighthSecBPSEn, highReset);
	input clk;
	input resetn;
	input eighthSecBPSEn;
	
	output reg highReset;

	reg [29:0] count;
	always @(posedge clk) begin
		if (!resetn) begin
			count <= 30'd0;
			highReset <= 1'd1;
		end
		else if (eighthSecBPSEn) begin
			count <= count + 1'd1;
			if (count <= 30'd6249999 && count >= 30'd0) 
				highReset <= 1'd1;
			else if (count > 30'd6249999 && count <= 30'd11249999) 
				highReset <= 1'd0;
			else if (count == 30'd11250000)
				count <= 30'd0;
		end
		else begin
			highReset <= 1'd1;
			count <= 30'd0;
		end
	end
	
endmodule
	
module counter_Enable_delay (clk, resetn, Enable);
	input clk;
	input resetn;
	
	output reg Enable;

	reg [25:0] count;
	always @(posedge clk) begin
		if (!resetn) begin
			count <= 26'd0;
			Enable <= 1'd0;
		end
		else begin
			if (count == 26'd49999999) begin
				Enable <= 1'd1;
				count <= 26'd0;
			end
			else begin
				count <= count + 1'd1;
				Enable <= 1'd0;
			end
		end
	end
	
endmodule
	
module counter_14bit_address (Enable, resetn, clk, count);
	input Enable;
	input clk;
	input resetn;
	output reg [16:0] count;

	always @ (posedge clk) begin
	   if (resetn == 1'b0) 
			count <= 17'd0;
	   
	   else if (Enable) begin
			if (count[16:0] == 17'd76800) 
				count <= 17'd0;
			else
				count <= count + 1'b1;
		end
	end
endmodule

module counter_14bit_coordinate (Enable, resetn, clk, count);
	input Enable;
	input clk;
	input resetn;
	output reg [16:0] count;

	always @ (posedge clk) begin
	   if (resetn == 1'b0) 
			count <= 17'd0;
	   
	   else if (Enable) begin
			if (count[16:9] == 8'd239) 
				count <= 17'd0;
			else if (count[8:0] == 9'd319) begin
				count[8:0] <= 9'd0;
				count[16:9] <= count[16:9] + 1'b1;
			end
			else
				count[8:0] <= count[8:0] + 1'b1;
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