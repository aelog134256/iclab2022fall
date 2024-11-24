`define CYCLE_TIME 15

/*
============================================================================
    
    Date : 2022/11/17
    Author : EECS Lab
    
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
    Parameter :
        CG_MODE : control the cg_en
    
============================================================================
*/

module PATTERN(
    // Output signals
    clk,
    rst_n,
    cg_en,
    in_valid,
    in_data,
    in_mode,
    // Input signals
    out_valid,
    out_data
);
//======================================
//          I/O PORTS
//======================================
output reg               clk;
output reg             rst_n;
output reg             cg_en;
output reg          in_valid;
output reg [8:0]     in_data;
output reg [2:0]     in_mode;

input              out_valid;
input signed [9:0]  out_data;

//======================================
//      PARAMETERS & VARIABLES
//======================================
parameter PATNUM    = 5000;
parameter CG_MODE   = 0; // Control the cg_en
parameter CYCLE     = `CYCLE_TIME;
parameter DELAY     = 1000;
parameter DATA_MAX  = 512;
parameter DATA_NUM  = 9;
parameter OUT_NUM   = 3;
parameter MODE_MAX  = 8;
parameter STAGE_NUM = 3;
integer   SEED      = 5200122;

// PATTERN CONTROL
integer       i;
integer       j;
integer       k;
integer       m;
integer    stop;
integer     pat;
integer exe_lat;
integer out_lat;
integer tot_lat;

//======================================
//      DATA MODEL
//======================================
reg signed [8:0] raw_data[0:DATA_NUM-1];
reg [2:0]        mode;

reg signed [9:0] data[0:STAGE_NUM-1][0:DATA_NUM-1]; // (for original bin)  3 stage, each stage has 9 data
reg signed [9:0] gold[0:OUT_NUM-1];
reg signed [9:0] your[0:OUT_NUM-1];

// Stage 1
reg signed [8:0] gray_bin[0:DATA_NUM-1];

// Stage 2
integer max_s2;
integer min_s2;
integer diff;
integer mid_pt;

// Stage 3
integer tmp_data[0:DATA_NUM-1];

// Gold temp data
reg signed [9:0] sort_data[0:DATA_NUM-1];
integer sort_idx[0:DATA_NUM-1];

//***************************************
//      Show Info task
//***************************************
integer sIdx, dIdx, bIdx;
task show_raw_data; begin
    // Display raw data
    $write("\033[1;34m");
    $display("==========================================");
    $display("=            Original Data               =");
    $display("==========================================");
    $display("Idx :  Dec       Bin");
    for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
        $display("#%-2d : \033[1;33m%4d \033[1;32m%b\033[1;34m", dIdx, raw_data[dIdx], raw_data[dIdx]);
    end
    $write("\033[1;0m\n");
end endtask

task show_mode; begin
    // Display raw data
    $write("\033[1;34m");
    $display("==========================================");
    $display("=                 Mode                   =");
    $display("==========================================");
                $display("[ Mode    ] : %b", mode);
    if(mode[0]) $display("[ Mode[0] ] : Gray Code");
    else        $display("[ Mode[0] ] : ---");
    if(mode[1]) $display("[ Mode[1] ] : Add/Subtract half/difference");
    else        $display("[ Mode[1] ] : ---");
    if(mode[2]) $display("[ Mode[2] ] : SMA");
    else        $display("[ Mode[2] ] : ---");
                $display("[ ------- ] : Find max/median/min");
    $write("\033[1;0m\n");
end endtask

task show_data; begin
    // Display raw data
    $write("\033[1;34m");
    $display("==========================================");
    $display("=                 Data                   =");
    $display("==========================================");
    
    $display("[ Stage1 ] : \n");
    // Show Data
    $write (" Dec  : { ");
    for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
        if(dIdx == DATA_NUM-1) $write ("%4d \033[1;34m}\n\n", data[0][DATA_NUM-1]);
        else                   $write("\033[1;33m%4d, ", data[0][dIdx]);
    end
    if(mode[0]) begin
        $display("  Idx :        Bin");
        for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
            $display("  #%-2d : \033[1;32m%b\033[1;34m", dIdx, data[0][dIdx]);
        end
        $write("\n");
    end

    $display("[ Stage2 ] : \n");
    // Show max, min, diff, mid point
    if(mode[1]) begin
        $display(" Max  : \033[1;31m%4d\033[1;34m | Min : \033[1;31m%4d\033[1;34m", max_s2, min_s2);
        $display(" Diff : \033[1;31m%4d\033[1;34m | Mid : \033[1;31m%4d\033[1;34m\n", diff, mid_pt);
    end
    // Show Data
    $write (" Dec  : { ");
    for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
        if(dIdx == DATA_NUM-1) $write ("%4d \033[1;34m}\n\n", data[1][DATA_NUM-1]);
        else                   $write("\033[1;33m%4d, ", data[1][dIdx]);
    end
    if(mode[0]) begin
        $display("  Idx :        Bin");
        for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
            $display("  #%-2d : \033[1;32m%b\033[1;34m", dIdx, data[1][dIdx]);
        end
        $write("\n");
    end

    $display("[ Stage3 ] : \n");
    // Show Data
    $write (" Dec  : { ");
    for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
        if(dIdx == DATA_NUM-1) $write ("%4d \033[1;34m}\n\n", data[2][DATA_NUM-1]);
        else                   $write("\033[1;33m%4d, ", data[2][dIdx]);
    end
    if(mode[0]) begin
        $display("  Idx :        Bin");
        for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
            $display("  #%-2d : \033[1;32m%b\033[1;34m", dIdx, data[2][dIdx]);
        end
        $write("\n");
    end

    $display("[ Final Sort ] : \n");
    // Show Data
    $write (" Dec  : { ");
    for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
        if(dIdx == DATA_NUM-1) $write ("%4d \033[1;34m}\n\n", sort_data[DATA_NUM-1]);
        else                   $write("\033[1;33m%4d, ", sort_data[dIdx]);
    end
    $write (" Idx  : { ");
    for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
        if(dIdx == DATA_NUM-1) $write ("%4d \033[1;34m}\n\n", sort_idx[DATA_NUM-1]);
        else                   $write("\033[1;33m%4d, ", sort_idx[dIdx]);
    end

    $write("\033[1;0m\n");
end endtask

// Show gold and your
reg signed[9:0] show_your_tmp;
task show_gold_your; begin
    $write("\033[1;34m");
    $display("==========================================");
    $display("=               Output                   =");
    $display("==========================================");
    $display("            Max  Med  Min");
    $display("[ Gold ] : \n");
    // Show Data
    $write (" Dec  : { ");
    for(dIdx=0 ; dIdx<OUT_NUM ; dIdx=dIdx+1) begin
        if(dIdx == OUT_NUM-1) $write("%4d \033[1;34m}\n\n", gold[OUT_NUM-1]);
        else                  $write("\033[1;33m%4d, ", gold[dIdx]);
    end
    if(mode[0]) begin
        $display("  Idx :        Bin");
        for(dIdx=0 ; dIdx<OUT_NUM ; dIdx=dIdx+1) begin
            $display("  #%-2d : \033[1;32m%b\033[1;34m", dIdx, gold[dIdx]);
        end
        $write("\n");
    end

    $display("[ Your ] : \n");
    // Show Data
    $write (" Dec  : { ");
    for(dIdx=0 ; dIdx<OUT_NUM ; dIdx=dIdx+1) begin
        if(dIdx == OUT_NUM-1) $write("%4d \033[1;34m}\n\n", your[dIdx]);
        else                  $write("\033[1;31m%4d, ", your[dIdx]);
    end
    if(mode[0]) begin
        $display("  Idx :        Bin");
        for(dIdx=0 ; dIdx<OUT_NUM ; dIdx=dIdx+1) begin
            $display("  #%-2d : \033[1;32m%b\033[1;34m", dIdx, your[dIdx]);
        end
        $write("\n");
    end

    $write("\033[1;0m\n");
end endtask

task show_gray_tmp_data; begin
    
    if(mode[0]) begin
        $write("\033[1;34m");
        $display("==========================================");
        $display("=            Gray Code Process           =");
        $display("==========================================");

        $display("  Idx :       Bin");
        for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
            $display("  #%-2d : \033[1;32m%b\033[1;34m", dIdx, gray_bin[dIdx]);
        end

        $write("\033[1;0m\n");
    end
end endtask

//***************************************
//      Modifier API
//***************************************
// Convert gray code to decimal
function signed[8:0] gray2dec_8b;
    input signed [8:0] in;
begin
    gray2dec_8b = in[8] ? -in[7:0] : in[7:0];
end endfunction

function signed[9:0] gray2dec_9b;
    input signed [9:0] in;
begin
    gray2dec_9b = in[9] ? -in[8:0] : in[8:0];
end endfunction

// Convert decimal to gray code
function signed[8:0] dec2gray_8b;
    input signed [8:0] in;
begin
    dec2gray_8b = in[8] ? (~in[7:0] + 1'd1) : in[7:0];
end endfunction

function signed[9:0] dec2gray_9b;
    input signed [9:0] in;
begin
    dec2gray_9b = in[9] ? (~in[8:0] + 1'd1) : in[8:0];
end endfunction

// Calculate stage 1 data
task cal_stage1; begin
    // Processing data
    for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
        gray_bin[dIdx] = raw_data[dIdx];
    end
    if(mode[0]) begin
        // Gray code mode
        for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
            for(bIdx=6 ; bIdx>=0 ; bIdx=bIdx-1) begin
                gray_bin[dIdx][bIdx] = gray_bin[dIdx][bIdx+1] ^ gray_bin[dIdx][bIdx];
            end
        end
    end
    // Decimal data
    for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
        if(mode[0]) data[0][dIdx] = gray2dec_9b({gray_bin[dIdx][8], {1'b0, gray_bin[dIdx][7:0]}});
        else        data[0][dIdx] = gray_bin[dIdx];
    end
end endtask

// Calculate stage 2 data
task cal_stage2; begin
    // Find the max, min, mid, diff, point
    max_s2 = -1024;
    min_s2 = 1024;
    if(mode[1]) begin
        for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
            if(max_s2 < data[0][dIdx]) max_s2 = data[0][dIdx];
            if(min_s2 > data[0][dIdx]) min_s2 = data[0][dIdx];
        end
        diff   = (max_s2 - min_s2)/2;
        mid_pt = (max_s2 + min_s2)/2;
        for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
            if(data[0][dIdx] > mid_pt)      data[1][dIdx] = data[0][dIdx] - diff;
            else if(data[0][dIdx] < mid_pt) data[1][dIdx] = data[0][dIdx] + diff;
            else                                data[1][dIdx] = data[0][dIdx];
        end
    end
    else begin
        for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
            data[1][dIdx] = data[0][dIdx];
        end
    end
end endtask

// Calculate stage 3 data
task cal_stage3; begin
    // SMA
    if(mode[2]) begin
        for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
            if(dIdx == 0)               tmp_data[dIdx] = (data[1][DATA_NUM-1] + data[1][dIdx] + data[1][dIdx+1])/3;
            else if(dIdx == DATA_NUM-1) tmp_data[dIdx] = (data[1][dIdx-1]     + data[1][dIdx] + data[1][0])/3;
            else                        tmp_data[dIdx] = (data[1][dIdx-1]     + data[1][dIdx] + data[1][dIdx+1])/3;
        end
    end
    else begin
        for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
            tmp_data[dIdx] = data[1][dIdx];
        end
    end
    for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
        data[2][dIdx] = tmp_data[dIdx];
    end
end endtask

// Calculate final data
integer swap_tmp;
task cal_sort; begin
    for(dIdx=0 ; dIdx<DATA_NUM ; dIdx=dIdx+1) begin
        sort_data[dIdx] = data[2][dIdx];
        sort_idx[dIdx] = dIdx;
    end
    for(dIdx=0 ; dIdx<DATA_NUM-1 ; dIdx=dIdx+1)begin
        for(bIdx=0 ; bIdx<DATA_NUM-dIdx-1 ; bIdx=bIdx+1) begin
            if(sort_data[bIdx] > sort_data[bIdx+1]) begin
                swap_tmp = sort_data[bIdx];
                sort_data[bIdx] = sort_data[bIdx+1];
                sort_data[bIdx+1] = swap_tmp;
                swap_tmp = sort_idx[bIdx];
                sort_idx[bIdx] = sort_idx[bIdx+1];
                sort_idx[bIdx+1] = swap_tmp;
            end
        end
    end
    gold[0] = sort_data[DATA_NUM-1]; // Max
    gold[1] = sort_data[DATA_NUM/2]; // Median
    gold[2] = sort_data[0]; // Min
end endtask

//======================================
//      MAIN
//======================================
initial exe_task;

//======================================
//      CLOCK
//======================================
initial clk = 1'b0;
always #(CYCLE/2.0) clk = ~clk;

//======================================
//      TASKS
//======================================
task exe_task; begin
    reset_task;
    for (pat=0 ; pat<PATNUM ; pat=pat+1) begin
        input_task;
        cal_task;
        wait_task;
        check_task;
        // Print Pass Info and accumulate the total latency
        $display("\033[0;34mPASS PATTERN NO.%4d,\033[m \033[0;32m Cycles: %3d\033[m", pat ,exe_lat);
    end
    final_check_task;
    pass_task;
end endtask
 
//**************************************
//      Reset Task
//**************************************
task reset_task; begin

    force clk = 0;
    rst_n     = 1;

    cg_en     = CG_MODE;
    in_valid  = 0;
    in_data   = 'dx;
    in_mode   = 'dx;

    tot_lat = 0;

    #(CYCLE/2.0) rst_n = 0;
    #(CYCLE/2.0) rst_n = 1;
    if (out_valid !== 0 || out_data !== 0) begin
        $display("                                           `:::::`                                                       ");
        $display("                                          .+-----++                                                      ");
        $display("                .--.`                    o:------/o                                                      ");
        $display("              /+:--:o/                   //-------y.          -//:::-        `.`                         ");
        $display("            `/:------y:                  `o:--::::s/..``    `/:-----s-    .:/:::+:                       ");
        $display("            +:-------:y                `.-:+///::-::::://:-.o-------:o  `/:------s-                      ");
        $display("            y---------y-        ..--:::::------------------+/-------/+ `+:-------/s                      ");
        $display("           `s---------/s       +:/++/----------------------/+-------s.`o:--------/s                      ");
        $display("           .s----------y-      o-:----:---------------------/------o: +:---------o:                      ");
        $display("           `y----------:y      /:----:/-------/o+----------------:+- //----------y`                      ");
        $display("            y-----------o/ `.--+--/:-/+--------:+o--------------:o: :+----------/o                       ");
        $display("            s:----------:y/-::::::my-/:----------/---------------+:-o-----------y.                       ");
        $display("            -o----------s/-:hmmdy/o+/:---------------------------++o-----------/o                        ");
        $display("             s:--------/o--hMMMMMh---------:ho-------------------yo-----------:s`                        ");
        $display("             :o--------s/--hMMMMNs---------:hs------------------+s------------s-                         ");
        $display("              y:-------o+--oyhyo/-----------------------------:o+------------o-                          ");
        $display("              -o-------:y--/s--------------------------------/o:------------o/                           ");
        $display("               +/-------o+--++-----------:+/---------------:o/-------------+/                            ");
        $display("               `o:-------s:--/+:-------/o+-:------------::+d:-------------o/                             ");
        $display("                `o-------:s:---ohsoosyhh+----------:/+ooyhhh-------------o:                              ");
        $display("                 .o-------/d/--:h++ohy/---------:osyyyyhhyyd-----------:o-                               ");
        $display("                 .dy::/+syhhh+-::/::---------/osyyysyhhysssd+---------/o`                                ");
        $display("                  /shhyyyymhyys://-------:/oyyysyhyydysssssyho-------od:                                 ");
        $display("                    `:hhysymmhyhs/:://+osyyssssydyydyssssssssyyo+//+ymo`                                 ");
        $display("                      `+hyydyhdyyyyyyyyyyssssshhsshyssssssssssssyyyo:`                                   ");
        $display("                        -shdssyyyyyhhhhhyssssyyssshssssssssssssyy+.    Output signal should be 0         ");
        $display("                         `hysssyyyysssssssssssssssyssssssssssshh+                                        ");
        $display("                        :yysssssssssssssssssssssssssssssssssyhysh-     after the reset signal is asserted");
        $display("                      .yyhhdo++oosyyyyssssssssssssssssssssssyyssyh/                                      ");
        $display("                      .dhyh/--------/+oyyyssssssssssssssssssssssssy:   at %4d ps                         ", $time*1000);
        $display("                       .+h/-------------:/osyyysssssssssssssssyyh/.                                      ");
        $display("                        :+------------------::+oossyyyyyyyysso+/s-                                       ");
        $display("                       `s--------------------------::::::::-----:o                                       ");
        $display("                       +:----------------------------------------y`                                      ");
        repeat(5) #(CYCLE);
        $finish;
    end
    #(CYCLE/2.0) release clk;
end endtask

//**************************************
//      Input Task
//**************************************
task input_task; begin
    repeat(({$random(SEED)} % 4 + 2)) @(negedge clk);
    mode = {$random(SEED)} % MODE_MAX;
    for(i=0 ; i<DATA_NUM ; i=i+1) begin
        raw_data[i] = {$random(SEED)} % DATA_MAX;
    end

    for(i=0 ; i<DATA_NUM ; i=i+1) begin
        // Overlap check
        if ( out_valid === 1 ) begin
            $display("                                                                 ``...`                                ");
            $display("     Out_valid can't overlap in_valid!!!                      `.-:::///:-::`                           "); 
            $display("                                                            .::-----------/s.                          "); 
            $display("                                                          `/+-----------.--+s.`                        "); 
            $display("                                                         .+y---------------/m///:-.                    "); 
            $display("                         ``.--------.-..``            `:+/mo----------:/+::ys----/++-`                 "); 
            $display("                     `.:::-:----------:::://-``     `/+:--yy----/:/oyo+/:+o/-------:+o:-:/++//::.`     "); 
            $display("                  `-//::-------------------:/++:.` .+/----/ho:--:/+/:--//:-----------:sd/------://:`   "); 
            $display("                .:+/----------------------:+ooshdyss:-------::-------------------------od:--------::   ");
            $display("              ./+:--------------------:+ssosssyyymh-------------------------------------+h/---------   ");
            $display("             :s/-------------------:osso+osyssssdd:--------------------------------------+myoos+/:--   ");
            $display("           `++-------------------:oso+++os++osshm:----------------------------------------ss--/:---/   ");
            $display("          .s/-------------------sho+++++++ohyyodo-----------------------------------------:ds+//+/:.   "); 
            $display("         .y/------------------/ys+++++++++sdsdym:------------------------------------------/y---.`     "); 
            $display("        .d/------------------oy+++++++++++omyhNd--------------------------------------------+:         "); 
            $display("       `yy------------------+h++++++++++++ydhohy---------------------------------------------+.        "); 
            $display("       -m/-----------------:ho++++++++++++odyhoho--------------------/++:---------------------:        "); 
            $display("       +y------------------ss+++++++++++ossyoshod+-----------------+ss++y:--------------------+`       "); 
            $display("       y+-//::------------:ho++++++++++osyhddyyoom/---------------::------------------/syh+--+/        "); 
            $display("      `hy:::::////:-/:----+d+++++++++++++++++oshhhd--------------------------------------/m+++`        "); 
            $display("      `hs--------/oo//+---/d++++++++++++++++++++sdN+-------------------------------:------:so`         "); 
            $display("       :s----------:+y++:-/d++++++++++++++++++++++sh+--------------:+-----+--------s--::---os          "); 
            $display("       .h------------:ssy-:mo++++++++++++++++++++++om+---------------+s++ys----::-:s/+so---/+/.        "); 
            $display("    `:::yy-------------/do-hy+++++o+++++++++++++++++oyyo--------------::::--:///++++o+/:------y.       "); 
            $display("  `:/:---ho-------------:yoom+++++hsh++++++++++++ossyyhNs---------------------+hmNmdys:-------h.       "); 
            $display(" `/:-----:y+------------.-sshy++++ohNy++++++++sso+/:---sy--------------------/NMMMMMNhs-----+s/        "); 
            $display(" +:-------:ho-------------:homo+++++hmo+++++oho:--------ss///////:------------yNMMMNdoy//+shd/`        "); 
            $display(" y---------:hs/------------+yod++++++hdo+++odo------------::::://+oo+o/--------/oso+oo::/sy+:o/        "); 
            $display(" y----/+:---::so:----------/m-sdo+oyo+ydo+ody------------------------/oo/------:/+oo/-----::--h.       "); 
            $display(" oo---/ss+:----:/----------+y--+hyooysoydshh----------------------------ohosshhs++:----------:y`       "); 
            $display(" `/oo++oosyo/:------------:yy++//sdysyhhydNdo:---------------------------shdNN+-------------+y-        "); 
            $display("    ``...``.-:/+////::-::/:.`.-::---::+oosyhdhs+/:-----------------------/s//oy:---------:os+.         "); 
            $display("               `.-:://---.                 ````.:+o/::-----------------:/o`  `-://::://:---`           "); 
            $display("                                                  `.-//+o////::/::///++:.`           ``                "); 
            $display("                                                        ``..-----....`                                 ");
            repeat(5) @(negedge clk);
            $finish;
        end

        // Send data
        in_valid = 1;
        in_data  = raw_data[i];
        if(i==0) in_mode = mode;
        @(negedge clk);
        in_valid = 0;
        in_data  = 'dx;
        in_mode  = 'dx;
    end


end endtask

//**************************************
//      Calculation Task
//**************************************
task cal_task; begin
    cal_stage1;
    cal_stage2;
    cal_stage3;
    cal_sort;
end endtask

//**************************************
//      Wait Task
//**************************************
task wait_task; begin
    exe_lat = -1;
    while (out_valid !== 1) begin
        if (out_data !== 0) begin
            $display("                                           `:::::`                                                       ");
            $display("                                          .+-----++                                                      ");
            $display("                .--.`                    o:------/o                                                      ");
            $display("              /+:--:o/                   //-------y.          -//:::-        `.`                         ");
            $display("            `/:------y:                  `o:--::::s/..``    `/:-----s-    .:/:::+:                       ");
            $display("            +:-------:y                `.-:+///::-::::://:-.o-------:o  `/:------s-                      ");
            $display("            y---------y-        ..--:::::------------------+/-------/+ `+:-------/s                      ");
            $display("           `s---------/s       +:/++/----------------------/+-------s.`o:--------/s                      ");
            $display("           .s----------y-      o-:----:---------------------/------o: +:---------o:                      ");
            $display("           `y----------:y      /:----:/-------/o+----------------:+- //----------y`                      ");
            $display("            y-----------o/ `.--+--/:-/+--------:+o--------------:o: :+----------/o                       ");
            $display("            s:----------:y/-::::::my-/:----------/---------------+:-o-----------y.                       ");
            $display("            -o----------s/-:hmmdy/o+/:---------------------------++o-----------/o                        ");
            $display("             s:--------/o--hMMMMMh---------:ho-------------------yo-----------:s`                        ");
            $display("             :o--------s/--hMMMMNs---------:hs------------------+s------------s-                         ");
            $display("              y:-------o+--oyhyo/-----------------------------:o+------------o-                          ");
            $display("              -o-------:y--/s--------------------------------/o:------------o/                           ");
            $display("               +/-------o+--++-----------:+/---------------:o/-------------+/                            ");
            $display("               `o:-------s:--/+:-------/o+-:------------::+d:-------------o/                             ");
            $display("                `o-------:s:---ohsoosyhh+----------:/+ooyhhh-------------o:                              ");
            $display("                 .o-------/d/--:h++ohy/---------:osyyyyhhyyd-----------:o-                               ");
            $display("                 .dy::/+syhhh+-::/::---------/osyyysyhhysssd+---------/o`                                ");
            $display("                  /shhyyyymhyys://-------:/oyyysyhyydysssssyho-------od:                                 ");
            $display("                    `:hhysymmhyhs/:://+osyyssssydyydyssssssssyyo+//+ymo`                                 ");
            $display("                      `+hyydyhdyyyyyyyyyyssssshhsshyssssssssssssyyyo:`                                   ");
            $display("                        -shdssyyyyyhhhhhyssssyyssshssssssssssssyy+.    Output signal should be 0         ");
            $display("                         `hysssyyyysssssssssssssssyssssssssssshh+                                        ");
            $display("                        :yysssssssssssssssssssssssssssssssssyhysh-     when the out_valid is pulled down ");
            $display("                      .yyhhdo++oosyyyyssssssssssssssssssssssyyssyh/                                      ");
            $display("                      .dhyh/--------/+oyyyssssssssssssssssssssssssy:   at %4d ps                         ", $time*1000);
            $display("                       .+h/-------------:/osyyysssssssssssssssyyh/.                                      ");
            $display("                        :+------------------::+oossyyyyyyyysso+/s-                                       ");
            $display("                       `s--------------------------::::::::-----:o                                       ");
            $display("                       +:----------------------------------------y`                                      ");
            repeat(5) #(CYCLE);
            $finish;
        end
        if (exe_lat == DELAY) begin
            $display("                                   ..--.                                ");
            $display("                                `:/:-:::/-                              ");
            $display("                                `/:-------o                             ");
            $display("                                /-------:o:                             "); 
            $display("                                +-:////+s/::--..                        ");
            $display("    The execution latency      .o+/:::::----::::/:-.       at %-12d ps  ", $time*1000);
            $display("    is over %5d   cycles    `:::--:/++:----------::/:.                ", DELAY);
            $display("                            -+:--:++////-------------::/-               ");
            $display("                            .+---------------------------:/--::::::.`   ");
            $display("                          `.+-----------------------------:o/------::.  ");
            $display("                       .-::-----------------------------:--:o:-------:  ");
            $display("                     -:::--------:/yy------------------/y/--/o------/-  ");
            $display("                    /:-----------:+y+:://:--------------+y--:o//:://-   ");
            $display("                   //--------------:-:+ssoo+/------------s--/. ````     ");
            $display("                   o---------:/:------dNNNmds+:----------/-//           ");
            $display("                   s--------/o+:------yNNNNNd/+--+y:------/+            ");
            $display("                 .-y---------o:-------:+sso+/-:-:yy:------o`            ");
            $display("              `:oosh/--------++-----------------:--:------/.            ");
            $display("              +ssssyy--------:y:---------------------------/            ");
            $display("              +ssssyd/--------/s/-------------++-----------/`           ");
            $display("              `/yyssyso/:------:+o/::----:::/+//:----------+`           ");
            $display("             ./osyyyysssso/------:/++o+++///:-------------/:            ");
            $display("           -osssssssssssssso/---------------------------:/.             ");
            $display("         `/sssshyssssssssssss+:---------------------:/+ss               ");
            $display("        ./ssssyysssssssssssssso:--------------:::/+syyys+               ");
            $display("     `-+sssssyssssssssssssssssso-----::/++ooooossyyssyy:                ");
            $display("     -syssssyssssssssssssssssssso::+ossssssssssssyyyyyss+`              ");
            $display("     .hsyssyssssssssssssssssssssyssssssssssyhhhdhhsssyssso`             ");
            $display("     +/yyshsssssssssssssssssssysssssssssyhhyyyyssssshysssso             ");
            $display("    ./-:+hsssssssssssssssssssssyyyyyssssssssssssssssshsssss:`           ");
            $display("    /---:hsyysyssssssssssssssssssssssssssssssssssssssshssssy+           ");
            $display("    o----oyy:-:/+oyysssssssssssssssssssssssssssssssssshssssy+-          ");
            $display("    s-----++-------/+sysssssssssssssssssssssssssssssyssssyo:-:-         ");
            $display("    o/----s-----------:+syyssssssssssssssssssssssyso:--os:----/.        ");
            $display("    `o/--:o---------------:+ossyysssssssssssyyso+:------o:-----:        ");
            $display("      /+:/+---------------------:/++ooooo++/:------------s:---::        ");
            $display("       `/o+----------------------------------------------:o---+`        ");
            $display("         `+-----------------------------------------------o::+.         ");
            $display("          +-----------------------------------------------/o/`          ");
            $display("          ::----------------------------------------------:-            ");
            repeat(5) @(negedge clk);
            $finish; 
        end
        exe_lat = exe_lat + 1;
        @(negedge clk);
    end
end endtask

//**************************************
//      Check Task
//**************************************
task check_task; begin
    out_lat = 0;
    while (out_valid === 1) begin
        if (out_lat == OUT_NUM) begin
            $display("                                                                                ");
            $display("                                                   ./+oo+/.                     ");
            $display("    Out cycles is more than %-2d                    /s:-----+s`     at %-12d ps ", OUT_NUM, $time*1000);
            $display("                                                  y/-------:y                   ");
            $display("                                             `.-:/od+/------y`                  ");
            $display("                               `:///+++ooooooo+//::::-----:/y+:`                ");
            $display("                              -m+:::::::---------------------::o+.              ");
            $display("                             `hod-------------------------------:o+             ");
            $display("                       ./++/:s/-o/--------------------------------/s///::.      ");
            $display("                      /s::-://--:--------------------------------:oo/::::o+     ");
            $display("                    -+ho++++//hh:-------------------------------:s:-------+/    ");
            $display("                  -s+shdh+::+hm+--------------------------------+/--------:s    ");
            $display("                 -s:hMMMMNy---+y/-------------------------------:---------//    ");
            $display("                 y:/NMMMMMN:---:s-/o:-------------------------------------+`    ");
            $display("                 h--sdmmdy/-------:hyssoo++:----------------------------:/`     ");
            $display("                 h---::::----------+oo+/::/+o:---------------------:+++s-`      ");
            $display("                 s:----------------/s+///------------------------------o`       ");
            $display("           ``..../s------------------::--------------------------------o        ");
            $display("       -/oyhyyyyyym:----------------://////:--------------------------:/        ");
            $display("      /dyssyyyssssyh:-------------/o+/::::/+o/------------------------+`        ");
            $display("    -+o/---:/oyyssshd/-----------+o:--------:oo---------------------:/.         ");
            $display("  `++--------:/sysssddy+:-------/+------------s/------------------://`          ");
            $display(" .s:---------:+ooyysyyddoo++os-:s-------------/y----------------:++.            ");
            $display(" s:------------/yyhssyshy:---/:o:-------------:dsoo++//:::::-::+syh`            ");
            $display("`h--------------shyssssyyms+oyo:--------------/hyyyyyyyyyyyysyhyyyy`            ");
            $display("`h--------------:yyssssyyhhyy+----------------+dyyyysssssssyyyhs+/.             ");
            $display(" s:--------------/yysssssyhy:-----------------shyyyyyhyyssssyyh.                ");
            $display(" .s---------------+sooosyyo------------------/yssssssyyyyssssyo                 ");
            $display("  /+-------------------:++------------------:ysssssssssssssssy-                 ");
            $display("  `s+--------------------------------------:syssssssssssssssyo                  ");
            $display("`+yhdo--------------------:/--------------:syssssssssssssssyy.                  ");
            $display("+yysyhh:-------------------+o------------/ysyssssssssssssssy/                   ");
            $display(" /hhysyds:------------------y-----------/+yyssssssssssssssyh`                   ");
            $display(" .h-+yysyds:---------------:s----------:--/yssssssssssssssym:                   ");
            $display(" y/---oyyyyhyo:-----------:o:-------------:ysssssssssyyyssyyd-                  ");
            $display("`h------+syyyyhhsoo+///+osh---------------:ysssyysyyyyysssssyd:                 ");
            $display("/s--------:+syyyyyyyyyyyyyyhso/:-------::+oyyyyhyyyysssssssyy+-                 ");
            $display("+s-----------:/osyyysssssssyyyyhyyyyyyyydhyyyyyyssssssssyys/`                   ");
            $display("+s---------------:/osyyyysssssssssssssssyyhyyssssssyyyyso/y`                    ");
            $display("/s--------------------:/+ossyyyyyyssssssssyyyyyyysso+:----:+                    ");
            $display(".h--------------------------:::/++oooooooo+++/:::----------o`                   ");
            repeat(5) @(negedge clk);
            $finish;
        end

        your[out_lat] = out_data;

        out_lat = out_lat + 1;
        @(negedge clk);
    end
    for(i=0 ; i<OUT_NUM ; i=i+1) begin
        if(your[i] !== gold[i]) begin
            $display("                                                                                ");
            $display("                                                   ./+oo+/.                     ");
            $display("    Out is not correct!!!!!                       /s:-----+s`     at %-12d ps   ",$time*1000);
            $display("                                                  y/-------:y                   ");
            $display("                                             `.-:/od+/------y`                  ");
            $display("                               `:///+++ooooooo+//::::-----:/y+:`                ");
            $display("                              -m+:::::::---------------------::o+.              ");
            $display("                             `hod-------------------------------:o+             ");
            $display("                       ./++/:s/-o/--------------------------------/s///::.      ");
            $display("                      /s::-://--:--------------------------------:oo/::::o+     ");
            $display("                    -+ho++++//hh:-------------------------------:s:-------+/    ");
            $display("                  -s+shdh+::+hm+--------------------------------+/--------:s    ");
            $display("                 -s:hMMMMNy---+y/-------------------------------:---------//    ");
            $display("                 y:/NMMMMMN:---:s-/o:-------------------------------------+`    ");
            $display("                 h--sdmmdy/-------:hyssoo++:----------------------------:/`     ");
            $display("                 h---::::----------+oo+/::/+o:---------------------:+++s-`      ");
            $display("                 s:----------------/s+///------------------------------o`       ");
            $display("           ``..../s------------------::--------------------------------o        ");
            $display("       -/oyhyyyyyym:----------------://////:--------------------------:/        ");
            $display("      /dyssyyyssssyh:-------------/o+/::::/+o/------------------------+`        ");
            $display("    -+o/---:/oyyssshd/-----------+o:--------:oo---------------------:/.         ");
            $display("  `++--------:/sysssddy+:-------/+------------s/------------------://`          ");
            $display(" .s:---------:+ooyysyyddoo++os-:s-------------/y----------------:++.            ");
            $display(" s:------------/yyhssyshy:---/:o:-------------:dsoo++//:::::-::+syh`            ");
            $display("`h--------------shyssssyyms+oyo:--------------/hyyyyyyyyyyyysyhyyyy`            ");
            $display("`h--------------:yyssssyyhhyy+----------------+dyyyysssssssyyyhs+/.             ");
            $display(" s:--------------/yysssssyhy:-----------------shyyyyyhyyssssyyh.                ");
            $display(" .s---------------+sooosyyo------------------/yssssssyyyyssssyo                 ");
            $display("  /+-------------------:++------------------:ysssssssssssssssy-                 ");
            $display("  `s+--------------------------------------:syssssssssssssssyo                  ");
            $display("`+yhdo--------------------:/--------------:syssssssssssssssyy.                  ");
            $display("+yysyhh:-------------------+o------------/ysyssssssssssssssy/                   ");
            $display(" /hhysyds:------------------y-----------/+yyssssssssssssssyh`                   ");
            $display(" .h-+yysyds:---------------:s----------:--/yssssssssssssssym:                   ");
            $display(" y/---oyyyyhyo:-----------:o:-------------:ysssssssssyyyssyyd-                  ");
            $display("`h------+syyyyhhsoo+///+osh---------------:ysssyysyyyyysssssyd:                 ");
            $display("/s--------:+syyyyyyyyyyyyyyhso/:-------::+oyyyyhyyyysssssssyy+-                 ");
            $display("+s-----------:/osyyysssssssyyyyhyyyyyyyydhyyyyyyssssssssyys/`                   ");
            $display("+s---------------:/osyyyysssssssssssssssyyhyyssssssyyyyso/y`                    ");
            $display("/s--------------------:/+ossyyyyyyssssssssyyyyyyysso+:----:+                    ");
            $display(".h--------------------------:::/++oooooooo+++/:::----------o`                   ");
            show_raw_data;
            show_gray_tmp_data;
            show_mode;
            show_data;
            show_gold_your;
            repeat(5) @(negedge clk);
            $finish;
        end
    end
end endtask

task final_check_task; begin
    for(i=0 ; i<40 ; i=i+1) begin
        @(negedge clk);
        if(out_valid === 1) begin
            $display("                                                                 ``...`                                ");
            $display("     Out_valid can't be 1 after passing all pattern           `.-:::///:-::`                           "); 
            $display("                                                            .::-----------/s.                          "); 
            $display("                                                          `/+-----------.--+s.`                        "); 
            $display("                                                         .+y---------------/m///:-.                    "); 
            $display("                         ``.--------.-..``            `:+/mo----------:/+::ys----/++-`                 "); 
            $display("                     `.:::-:----------:::://-``     `/+:--yy----/:/oyo+/:+o/-------:+o:-:/++//::.`     "); 
            $display("                  `-//::-------------------:/++:.` .+/----/ho:--:/+/:--//:-----------:sd/------://:`   "); 
            $display("                .:+/----------------------:+ooshdyss:-------::-------------------------od:--------::   ");
            $display("              ./+:--------------------:+ssosssyyymh-------------------------------------+h/---------   ");
            $display("             :s/-------------------:osso+osyssssdd:--------------------------------------+myoos+/:--   ");
            $display("           `++-------------------:oso+++os++osshm:----------------------------------------ss--/:---/   ");
            $display("          .s/-------------------sho+++++++ohyyodo-----------------------------------------:ds+//+/:.   "); 
            $display("         .y/------------------/ys+++++++++sdsdym:------------------------------------------/y---.`     "); 
            $display("        .d/------------------oy+++++++++++omyhNd--------------------------------------------+:         "); 
            $display("       `yy------------------+h++++++++++++ydhohy---------------------------------------------+.        "); 
            $display("       -m/-----------------:ho++++++++++++odyhoho--------------------/++:---------------------:        "); 
            $display("       +y------------------ss+++++++++++ossyoshod+-----------------+ss++y:--------------------+`       "); 
            $display("       y+-//::------------:ho++++++++++osyhddyyoom/---------------::------------------/syh+--+/        "); 
            $display("      `hy:::::////:-/:----+d+++++++++++++++++oshhhd--------------------------------------/m+++`        "); 
            $display("      `hs--------/oo//+---/d++++++++++++++++++++sdN+-------------------------------:------:so`         "); 
            $display("       :s----------:+y++:-/d++++++++++++++++++++++sh+--------------:+-----+--------s--::---os          "); 
            $display("       .h------------:ssy-:mo++++++++++++++++++++++om+---------------+s++ys----::-:s/+so---/+/.        "); 
            $display("    `:::yy-------------/do-hy+++++o+++++++++++++++++oyyo--------------::::--:///++++o+/:------y.       "); 
            $display("  `:/:---ho-------------:yoom+++++hsh++++++++++++ossyyhNs---------------------+hmNmdys:-------h.       "); 
            $display(" `/:-----:y+------------.-sshy++++ohNy++++++++sso+/:---sy--------------------/NMMMMMNhs-----+s/        "); 
            $display(" +:-------:ho-------------:homo+++++hmo+++++oho:--------ss///////:------------yNMMMNdoy//+shd/`        "); 
            $display(" y---------:hs/------------+yod++++++hdo+++odo------------::::://+oo+o/--------/oso+oo::/sy+:o/        "); 
            $display(" y----/+:---::so:----------/m-sdo+oyo+ydo+ody------------------------/oo/------:/+oo/-----::--h.       "); 
            $display(" oo---/ss+:----:/----------+y--+hyooysoydshh----------------------------ohosshhs++:----------:y`       "); 
            $display(" `/oo++oosyo/:------------:yy++//sdysyhhydNdo:---------------------------shdNN+-------------+y-        "); 
            $display("    ``...``.-:/+////::-::/:.`.-::---::+oosyhdhs+/:-----------------------/s//oy:---------:os+.         "); 
            $display("               `.-:://---.                 ````.:+o/::-----------------:/o`  `-://::://:---`           "); 
            $display("                                                  `.-//+o////::/::///++:.`           ``                "); 
            $display("                                                        ``..-----....`                                 ");
            repeat(5) @(negedge clk);
            $finish;
        end
    end
end endtask

//**************************************
//      PASS Task
//**************************************
task pass_task; begin
    $display("\033[1;33m                `oo+oy+`                            \033[1;35m Congratulation!!! \033[1;0m                                   ");
    $display("\033[1;33m               /h/----+y        `+++++:             \033[1;35m PASS This Lab........Maybe \033[1;0m                          ");
    $display("\033[1;33m             .y------:m/+ydoo+:y:---:+o             \033[1;35m Total Latency : %-10d\033[1;0m                                ", tot_lat);
    $display("\033[1;33m              o+------/y--::::::+oso+:/y                                                                                     ");
    $display("\033[1;33m              s/-----:/:----------:+ooy+-                                                                                    ");
    $display("\033[1;33m             /o----------------/yhyo/::/o+/:-.`                                                                              ");
    $display("\033[1;33m            `ys----------------:::--------:::+yyo+                                                                           ");
    $display("\033[1;33m            .d/:-------------------:--------/--/hos/                                                                         ");
    $display("\033[1;33m            y/-------------------::ds------:s:/-:sy-                                                                         ");
    $display("\033[1;33m           +y--------------------::os:-----:ssm/o+`                                                                          ");
    $display("\033[1;33m          `d:-----------------------:-----/+o++yNNmms                                                                        ");
    $display("\033[1;33m           /y-----------------------------------hMMMMN.                                                                      ");
    $display("\033[1;33m           o+---------------------://:----------:odmdy/+.                                                                    ");
    $display("\033[1;33m           o+---------------------::y:------------::+o-/h                                                                    ");
    $display("\033[1;33m           :y-----------------------+s:------------/h:-:d                                                                    ");
    $display("\033[1;33m           `m/-----------------------+y/---------:oy:--/y                                                                    ");
    $display("\033[1;33m            /h------------------------:os++/:::/+o/:--:h-                                                                    ");
    $display("\033[1;33m         `:+ym--------------------------://++++o/:---:h/                                                                     ");
    $display("\033[1;31m        `hhhhhoooo++oo+/:\033[1;33m--------------------:oo----\033[1;31m+dd+                                                 ");
    $display("\033[1;31m         shyyyhhhhhhhhhhhso/:\033[1;33m---------------:+/---\033[1;31m/ydyyhs:`                                              ");
    $display("\033[1;31m         .mhyyyyyyhhhdddhhhhhs+:\033[1;33m----------------\033[1;31m:sdmhyyyyyyo:                                            ");
    $display("\033[1;31m        `hhdhhyyyyhhhhhddddhyyyyyo++/:\033[1;33m--------\033[1;31m:odmyhmhhyyyyhy                                            ");
    $display("\033[1;31m        -dyyhhyyyyyyhdhyhhddhhyyyyyhhhs+/::\033[1;33m-\033[1;31m:ohdmhdhhhdmdhdmy:                                           ");
    $display("\033[1;31m         hhdhyyyyyyyyyddyyyyhdddhhyyyyyhhhyyhdhdyyhyys+ossyhssy:-`                                                           ");
    $display("\033[1;31m         `Ndyyyyyyyyyyymdyyyyyyyhddddhhhyhhhhhhhhy+/:\033[1;33m-------::/+o++++-`                                            ");
    $display("\033[1;31m          dyyyyyyyyyyyyhNyydyyyyyyyyyyhhhhyyhhy+/\033[1;33m------------------:/ooo:`                                         ");
    $display("\033[1;31m         :myyyyyyyyyyyyyNyhmhhhyyyyyhdhyyyhho/\033[1;33m-------------------------:+o/`                                       ");
    $display("\033[1;31m        /dyyyyyyyyyyyyyyddmmhyyyyyyhhyyyhh+:\033[1;33m-----------------------------:+s-                                      ");
    $display("\033[1;31m      +dyyyyyyyyyyyyyyydmyyyyyyyyyyyyyds:\033[1;33m---------------------------------:s+                                      ");
    $display("\033[1;31m      -ddhhyyyyyyyyyyyyyddyyyyyyyyyyyhd+\033[1;33m------------------------------------:oo              `-++o+:.`             ");
    $display("\033[1;31m       `/dhshdhyyyyyyyyyhdyyyyyyyyyydh:\033[1;33m---------------------------------------s/            -o/://:/+s             ");
    $display("\033[1;31m         os-:/oyhhhhyyyydhyyyyyyyyyds:\033[1;33m----------------------------------------:h:--.`      `y:------+os            ");
    $display("\033[1;33m         h+-----\033[1;31m:/+oosshdyyyyyyyyhds\033[1;33m-------------------------------------------+h//o+s+-.` :o-------s/y  ");
    $display("\033[1;33m         m:------------\033[1;31mdyyyyyyyyymo\033[1;33m--------------------------------------------oh----:://++oo------:s/d  ");
    $display("\033[1;33m        `N/-----------+\033[1;31mmyyyyyyyydo\033[1;33m---------------------------------------------sy---------:/s------+o/d  ");
    $display("\033[1;33m        .m-----------:d\033[1;31mhhyyyyyyd+\033[1;33m----------------------------------------------y+-----------+:-----oo/h  ");
    $display("\033[1;33m        +s-----------+N\033[1;31mhmyyyyhd/\033[1;33m----------------------------------------------:h:-----------::-----+o/m  ");
    $display("\033[1;33m        h/----------:d/\033[1;31mmmhyyhh:\033[1;33m-----------------------------------------------oo-------------------+o/h  ");
    $display("\033[1;33m       `y-----------so /\033[1;31mNhydh:\033[1;33m-----------------------------------------------/h:-------------------:soo  ");
    $display("\033[1;33m    `.:+o:---------+h   \033[1;31mmddhhh/:\033[1;33m---------------:/osssssoo+/::---------------+d+//++///::+++//::::::/y+`  ");
    $display("\033[1;33m   -s+/::/--------+d.   \033[1;31mohso+/+y/:\033[1;33m-----------:yo+/:-----:/oooo/:----------:+s//::-.....--:://////+/:`    ");
    $display("\033[1;33m   s/------------/y`           `/oo:--------:y/-------------:/oo+:------:/s:                                                 ");
    $display("\033[1;33m   o+:--------::++`              `:so/:-----s+-----------------:oy+:--:+s/``````                                             ");
    $display("\033[1;33m    :+o++///+oo/.                   .+o+::--os-------------------:oy+oo:`/o+++++o-                                           ");
    $display("\033[1;33m       .---.`                          -+oo/:yo:-------------------:oy-:h/:---:+oyo                                          ");
    $display("\033[1;33m                                          `:+omy/---------------------+h:----:y+//so                                         ");
    $display("\033[1;33m                                              `-ys:-------------------+s-----+s///om                                         ");
    $display("\033[1;33m                                                 -os+::---------------/y-----ho///om                                         ");
    $display("\033[1;33m                                                    -+oo//:-----------:h-----h+///+d                                         ");
    $display("\033[1;33m                                                       `-oyy+:---------s:----s/////y                                         ");
    $display("\033[1;33m                                                           `-/o+::-----:+----oo///+s                                         ");
    $display("\033[1;33m                                                               ./+o+::-------:y///s:                                         ");
    $display("\033[1;33m                                                                   ./+oo/-----oo/+h                                          ");
    $display("\033[1;33m                                                                       `://++++syo`                                          ");
    $display("\033[1;0m"); 
    repeat(5) @(negedge clk);
    $finish;
end endtask

endmodule
