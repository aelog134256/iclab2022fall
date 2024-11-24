`ifdef RTL
`define CYCLE_TIME 20
`endif
`ifdef GATE
`define CYCLE_TIME 20
`endif

`include "../00_TESTBED/MEM_MAP_define.v"
`include "../00_TESTBED/pseudo_DRAM.v"

/*
============================================================================
    
    Date : 2022/11/5
    Author : EECS Lab
    
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
    Debug method :
        Display :
            Display pic/se/cdf table
            Only display the 4x4 image of pic
                based on the location of se
        Debug file :
            1. GOLDEN_PIC.txt      ===> pic and se
            2. HISTOGRAM.txt       ===> cdf table (only for histogram pic)
            3. ORIGINAL_PIC_SE.txt ===> pic and se
            4. YOUR_PIC.txt        ===> you pic
            5. RESET_DRAM.txt      ===> Record the DRAM after reset
    
============================================================================
*/

module PATTERN #(parameter ID_WIDTH=4, DATA_WIDTH=128, ADDR_WIDTH=32)(
    clk          ,
    rst_n        ,
    in_valid     ,
    op           ,
    pic_no       ,
    se_no        ,
    busy         ,

    awid_s_inf   ,
    awaddr_s_inf ,
    awsize_s_inf ,
    awburst_s_inf,
    awlen_s_inf  ,
    awvalid_s_inf,
    awready_s_inf,

    wdata_s_inf  ,
    wlast_s_inf  ,
    wvalid_s_inf ,
    wready_s_inf ,

    bid_s_inf    ,
    bresp_s_inf  ,
    bvalid_s_inf ,
    bready_s_inf ,

    arid_s_inf   ,
    araddr_s_inf ,
    arlen_s_inf  ,
    arsize_s_inf ,
    arburst_s_inf,
    arvalid_s_inf,

    arready_s_inf,
    rid_s_inf    ,
    rdata_s_inf  ,
    rresp_s_inf  ,
    rlast_s_inf  ,
    rvalid_s_inf ,
    rready_s_inf 
);

//======================================
//          I/O PORTS
//======================================
output reg           clk;
output reg         rst_n;
output reg      in_valid;
output reg[3:0]   pic_no;
output reg[5:0]    se_no;
output reg[1:0]       op;
input               busy;

// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
       your AXI-4 interface could be designed as convertor in submodule(which used reg for output signal),
       therefore I declared output of AXI as wire  
*/

// axi write addr channel 
// src master
input  wire [ID_WIDTH-1:0]      awid_s_inf;
input  wire [ADDR_WIDTH-1:0]  awaddr_s_inf;
input  wire [2:0]             awsize_s_inf;
input  wire [1:0]            awburst_s_inf;
input  wire [7:0]              awlen_s_inf;
input  wire                  awvalid_s_inf;
// src slave
output wire                  awready_s_inf;
// -------------------------

// axi write data channel 
// src master
input  wire [DATA_WIDTH-1:0]   wdata_s_inf;
input  wire                    wlast_s_inf;
input  wire                   wvalid_s_inf;
// src slave
output wire                   wready_s_inf;

// axi write resp channel 
// src slave
output wire  [ID_WIDTH-1:0]      bid_s_inf;
output wire  [1:0]             bresp_s_inf;
output wire                   bvalid_s_inf;
// src master 
input  wire                   bready_s_inf;
// ------------------------

// axi read addr channel 
// src master
input  wire [ID_WIDTH-1:0]      arid_s_inf;
input  wire [ADDR_WIDTH-1:0]  araddr_s_inf;
input  wire [7:0]              arlen_s_inf;
input  wire [2:0]             arsize_s_inf;
input  wire [1:0]            arburst_s_inf;
input  wire                  arvalid_s_inf;
// src slave
output wire                  arready_s_inf;
// ------------------------

// axi read data channel 
// slave
output wire [ID_WIDTH-1:0]       rid_s_inf;
output wire [DATA_WIDTH-1:0]   rdata_s_inf;
output wire [1:0]              rresp_s_inf;
output wire                    rlast_s_inf;
output wire                   rvalid_s_inf;
// master
input  wire                   rready_s_inf;
// -----------------------------

//======================================
//      PARAMETERS & VARIABLES
//======================================
parameter PATNUM      = 10;
parameter CYCLE       = `CYCLE_TIME;
parameter DELAY       = 100000;
// OP
parameter OP_NUM      = 3;
// PIC
parameter PIC_ADDR    = 'h40000;
parameter PIC_SIZE    = 64; // 64 x 64
parameter PIC_NUM     = 16; // No.0 ~ No.15
// SE
parameter SE_ADDR     = 'h30000;
parameter SE_SIZE     = 4;  // 4 x 4
parameter SE_NUM      = 64; // No.0 ~ No.63
// SEED
integer   SEED        = 'd122;
// Reset DRAM
// The probability of changing target pic or se :
//      prob = NUMERATOR/DENOMINATOR
parameter NUMERATOR   = 1;
parameter DENOMINATOR = 10;
parameter SE_MAX      = 4;
parameter PIC_MAX     = 256;
integer RECORD_SEED;


integer      pat;
integer        i;
integer        j;
integer        m;
integer        n;
integer  exe_lat;
integer  tot_lat;

// FILE CONTROL
integer file_out;

//======================================
//      DATA MODEL
//======================================
reg[3:0] A_addr;
reg[5:0] B_addr;
reg[1:0]   mode;

integer    A[0:66][0:66];
integer      B[0:3][0:3];
integer    B_s[0:3][0:3];
integer your[0:63][0:63];
integer gold[0:63][0:63];

integer     max;
integer     min;
integer CDF_max;
integer CDF_min;

//======================================
//      DRAM CONNECTION
//======================================
pseudo_DRAM u_DRAM(

      .clk(clk),
      .rst_n(rst_n),

   .   awid_s_inf(   awid_s_inf),
   . awaddr_s_inf( awaddr_s_inf),
   . awsize_s_inf( awsize_s_inf),
   .awburst_s_inf(awburst_s_inf),
   .  awlen_s_inf(  awlen_s_inf),
   .awvalid_s_inf(awvalid_s_inf),
   .awready_s_inf(awready_s_inf),

   .  wdata_s_inf(  wdata_s_inf),
   .  wlast_s_inf(  wlast_s_inf),
   . wvalid_s_inf( wvalid_s_inf),
   . wready_s_inf( wready_s_inf),

   .    bid_s_inf(    bid_s_inf),
   .  bresp_s_inf(  bresp_s_inf),
   . bvalid_s_inf( bvalid_s_inf),
   . bready_s_inf( bready_s_inf),

   .   arid_s_inf(   arid_s_inf),
   . araddr_s_inf( araddr_s_inf),
   .  arlen_s_inf(  arlen_s_inf),
   . arsize_s_inf( arsize_s_inf),
   .arburst_s_inf(arburst_s_inf),
   .arvalid_s_inf(arvalid_s_inf),
   .arready_s_inf(arready_s_inf), 

   .    rid_s_inf(    rid_s_inf),
   .  rdata_s_inf(  rdata_s_inf),
   .  rresp_s_inf(  rresp_s_inf),
   .  rlast_s_inf(  rlast_s_inf),
   . rvalid_s_inf( rvalid_s_inf),
   . rready_s_inf( rready_s_inf)
);

//======================================
//              CLOCK
//======================================
initial clk = 1'b0;
always #(CYCLE/2.0) clk = ~clk;

//======================================
//              MAIN
//======================================
initial exe_task;

//======================================
//              TASKS
//======================================
task exe_task; begin
    reset_task;
    for ( pat=0 ; pat<PATNUM ; pat=pat+1 ) begin
        input_task;
        cal_task;
        wait_task;
        check_task;
        // change_dram_task;
        $display("\033[0;34mPASS PATTERN NO.%4d,\033[m \033[0;32m Cycles: %3d\033[m", pat ,exe_lat);
    end
    pass_task;
end endtask

//**************************************
//      Reset Task
//**************************************
task reset_task; begin
    force clk = 0;
    rst_n     = 1;
    in_valid  = 0;
    pic_no    = 4'dx;
    se_no     = 6'dx;
    op        = 2'dx;

    #(CYCLE/2.0) rst_n = 0;
    #(CYCLE/2.0) rst_n = 1;
    /*if ( busy !== 0 ) begin
        $display("\033[1;34m");
        $display("====================================");
        $display("Busy should be 0 after initial reset");
        $display("====================================");
        $display("\033[1;0m");
        repeat(5) #(CYCLE);
        $finish;
    end*/
    #(CYCLE/2.0) release clk;
    RECORD_SEED = SEED;
end endtask

//**************************************
//      Input Task
//**************************************
task input_task; begin
    repeat($urandom_range(3,1)) @(negedge clk);
    in_valid = 1;
    pic_no   = {$random(SEED)}%PIC_NUM;
    se_no    = {$random(SEED)}%SE_NUM;
    op       = {$random(SEED)}%OP_NUM;
   
    A_addr = pic_no;
    B_addr = se_no;
    mode   = op;

    @(negedge clk)
    if ( busy !== 0 ) begin
        $display("                                                                 ``...`                                ");
        $display("     Busy should be 1 after input is giving!!!                `.-:::///:-::`                           "); 
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
        $display("\033[1;0m");
        repeat(5) @(negedge clk);
    end
    in_valid = 0;
    pic_no   = 'dx;
    se_no    = 'dx;
    op       = 'dx;

end endtask

//**************************************
//      Wait Task
//**************************************
task wait_task; begin
    exe_lat = -1;
    @( negedge clk );
    while ( busy!==0 ) begin
        if (exe_lat == DELAY) begin
            $display("                                   ..--.                                ");
            $display("                                `:/:-:::/-                              ");
            $display("                                `/:-------o                             ");
            $display("                                /-------:o:                             ");
            $display("                                +-:////+s/::--..                        ");
            $display("    The execution latency      .o+/:::::----::::/:-.       at %-12d ps  ", $time*1000);
            $display("    is over %7d   cycles  `:::--:/++:----------::/:.                ", DELAY);
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
        @ (negedge clk); 
    end   
end endtask

//**************************************
//      Change DRAM Task
//**************************************
// Re-assign the value to the DRAM
integer addr;
task change_dram_task; begin
    if(({$random(SEED)}%DENOMINATOR) < NUMERATOR) begin
        $display("\033[33m\33[05m[ Reset the PIC/SE in DRAM ]\033[1;0m");

        // Reset the SE
        for(addr=SE_ADDR; addr<SE_ADDR+SE_SIZE*SE_SIZE*SE_NUM; addr=addr+'h1) begin
            // $display("%h", addr);
            u_DRAM.DRAM_r[addr] = {$random(SEED)} % SE_MAX;
        end

        // Reset the PIC
        for(addr=PIC_ADDR; addr<PIC_ADDR+PIC_SIZE*PIC_SIZE*PIC_NUM; addr=addr+'h1) begin
            // $display("%h", addr);
            u_DRAM.DRAM_r[addr] = {$random(SEED)} % PIC_MAX;
        end

        // Record the DRAM data
        file_out = $fopen($sformatf("RESET_DRAM_%0d.txt", pat), "w");
        $fwrite(file_out, "[ Reset DRAM Info ]\n");
        $fwrite(file_out, "* Current PAT : %0d\n", pat);
        $fwrite(file_out, "* SEED        : %0d\n\n", RECORD_SEED);
        
        $fwrite(file_out, "===================\n");
        $fwrite(file_out, "=     SE Info     =\n");
        $fwrite(file_out, "===================\n");
        for(addr=SE_ADDR; addr<SE_ADDR+SE_SIZE*SE_SIZE*SE_NUM; addr=addr+'h4) begin
            $fwrite(file_out, "@%5h\n", addr);
            $fwrite(file_out, "%h ",  u_DRAM.DRAM_r[addr]);
            $fwrite(file_out, "%h ",  u_DRAM.DRAM_r[addr+1]);
            $fwrite(file_out, "%h ",  u_DRAM.DRAM_r[addr+2]);
            $fwrite(file_out, "%h\n", u_DRAM.DRAM_r[addr+3]);
        end

        $fwrite(file_out,   "===================\n");
        $fwrite(file_out, "\n=     PIC Info    =\n");
        $fwrite(file_out,   "===================\n");
        for(addr=PIC_ADDR; addr<PIC_ADDR+PIC_SIZE*PIC_SIZE*PIC_NUM; addr=addr+'h4) begin
            $fwrite(file_out, "@%5h\n", addr);
            $fwrite(file_out, "%h ",  u_DRAM.DRAM_r[addr]);
            $fwrite(file_out, "%h ",  u_DRAM.DRAM_r[addr+1]);
            $fwrite(file_out, "%h ",  u_DRAM.DRAM_r[addr+2]);
            $fwrite(file_out, "%h\n", u_DRAM.DRAM_r[addr+3]);
        end
        $fclose(file_out);
    end
end endtask

//**************************************
//      Calculation Task
//**************************************
integer cdf[255:0];

task cal_task; begin

    // CDF list
    for (i=0;i<256;i=i+1)begin
        cdf[i] = 0;
    end
    
    // PIC A image
    max = 0;
    min = 255;
    for ( i=0 ; i<67 ; i=i+1 ) begin
        for ( j=0 ; j<67 ; j=j+1 ) begin
            if ( i>63 || j>63 ) A[i][j] = 0;
            else begin
                A[i][j] = u_DRAM.DRAM_r[ PIC_ADDR + (A_addr)*(PIC_SIZE*PIC_SIZE) + PIC_SIZE*i + j ];
                cdf[A[i][j]] = cdf[A[i][j]] + 1;
                if(min > A[i][j]) min = A[i][j];
            end
        end
    end
    
    // Accunalate CDF
    //$display(" cdf of %d is %d",0,cdf[0]);
    for ( i=1 ; i<256 ; i=i+1 ) begin
        cdf[i] = cdf[i] + cdf[i-1];
        //$display(" cdf of %d is %d",i,cdf[i]);
    end
    
    // SE B image
    for ( i=0 ; i<4 ; i=i+1 ) begin
        for ( j=0 ; j<4 ; j=j+1 ) begin
            B[i][j] = u_DRAM.DRAM_r[ SE_ADDR + (B_addr)*(SE_SIZE*SE_SIZE) + SE_SIZE*i + j ];
        end
    end

    // B symmetry image
    for ( i=0 ; i<SE_SIZE ; i=i+1 ) begin
        for ( j=0 ; j<SE_SIZE ; j=j+1 ) begin
            B_s[i][j] = B[3-i][3-j];
        end
    end

    // Gold image
    if ( mode==0 ) begin
        // Erosion
        for ( i=0 ; i<PIC_SIZE ; i=i+1 ) begin
            for ( j=0 ; j<PIC_SIZE ; j=j+1 ) begin
                gold[i][j] = A[i][j] - B[0][0];
                for ( m=0 ; m<SE_SIZE ; m=m+1 ) begin
                    for ( n=0 ; n<SE_SIZE ; n=n+1 ) begin
                        if ( (A[i+m][j+n] - B[m][n]) < 0 ) gold[i][j] = 0;
                        else                               if ( (A[i+m][j+n] - B[m][n]) < gold[i][j] ) gold[i][j] = A[i+m][j+n] - B[m][n];
                    end
                end
            end
        end
    end
    else if ( mode==1 ) begin
        // Dilation
        for ( i=0 ; i<PIC_SIZE ; i=i+1 ) begin
            for ( j=0 ; j<PIC_SIZE ; j=j+1 ) begin
                gold[i][j] = A[i][j] + B_s[0][0];
                for ( m=0 ; m<SE_SIZE ; m=m+1 ) begin
                    for ( n=0 ; n<SE_SIZE ; n=n+1 ) begin
                        if ( (A[i+m][j+n] + B_s[m][n]) > 255 ) gold[i][j] = 255;
                        else                                   if ( (A[i+m][j+n] + B_s[m][n]) > gold[i][j] ) gold[i][j] = A[i+m][j+n] + B_s[m][n];
                    end
                end
            end
        end
    end
    else begin
        CDF_min = cdf[min];
        CDF_max = 4096;
        // Histogram
        for ( i=0 ; i<PIC_SIZE ; i=i+1 )
            for ( j=0 ; j<PIC_SIZE ; j=j+1 ) 
                gold[i][j] = ((cdf[A[i][j]]-CDF_min)*255)/(CDF_max-CDF_min);
    end
end endtask

//**************************************
//      Check Task
//**************************************
task check_task; begin
    // PIC Answer image
    for ( i=0 ; i<PIC_SIZE ; i=i+1 ) begin
        for ( j=0 ; j<PIC_SIZE ; j=j+1 ) begin
            your[i][j] = u_DRAM.DRAM_r[ PIC_ADDR + (A_addr)*(PIC_SIZE*PIC_SIZE) + PIC_SIZE*i + j ];
        end
    end

    dump_ans_task;

    for ( i=0 ; i<PIC_SIZE ; i=i+1 ) begin
        for ( j=0 ; j<PIC_SIZE ; j=j+1 ) begin
            if ( your[i][j] !== gold[i][j] ) begin
                $display("\033[1;34m");
                $display("                                                                                ");
                $display("                                                   ./+oo+/.                     ");
                $display("    Your output is not correct                    /s:-----+s`     at %-12d ps   ", $time*1000);
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
                
                if ( mode==0 )      $display("              Erosion               ");
                else if ( mode==1 ) $display("              Dilation              ");
                else                $display("              Histogram             ");
                $display("====================================");

                $display("\033[1;34m");
                $display("The (\033[1;32m%2d\033[1;34m, \033[1;32m%2d\033[1;34m) pixel is wrong", i, j);
                $display("\033[1;0m");

                //***************************
                // Show the PIC and SE image
                //***************************
                if ( mode==0 || mode==1 ) begin
                
                    $display("\033[1;34m");
                    $display("Original image:");
                    $display("\033[1;0m");
                    for( m=0 ; m<SE_SIZE ; m=m+1 ) begin
                        for ( n=0 ; n<SE_SIZE ; n=n+1 ) begin
                            $write("%d", A[i+m][j+n]);
                        end
                        $display("");
                    end
                    
                    $display("\033[1;34m");
                    $display("SE image:");
                    $display("\033[1;0m");
                    for( m=0 ; m<SE_SIZE ; m=m+1 ) begin
                        for ( n=0 ; n<SE_SIZE ; n=n+1 ) begin
                            $write("%d", B[m][n]);
                        end
                        $display("");
                    end
                end
                else begin
                    $display("\033[1;34m");
                    $display("CDF table:");
                    $display("\033[1;32m");
                    $display("=================");
                    $display("| Value | Count |");
                    for ( m=0 ; m<256 ; m=m+1 ) begin
                        if ( cdf[m] != 0 )
                            $display("|  %4d |  %4d |", m, cdf[m]);
                    end
                    $display("=================");
                    $display("\033[1;0m");
                    
                    $display("\033[1;34m");
                    $display("The cdf of min value  : \033[1;32m%4d", cdf[min]);
                    $display("\033[1;0m");
                    
                    $display("\033[1;34m");
                    $display("The cdf of wrong valu : \033[1;32m%4d", cdf[A[i][j]]);
                    $display("\033[1;0m");

                    $display("\033[1;34m");
                    $display("Original image:");
                    $display("\033[1;0m");
                    for( m=0 ; m<SE_SIZE ; m=m+1 ) begin
                        for ( n=0 ; n<SE_SIZE ; n=n+1 ) begin
                            $write("%d", A[i+m][j+n]);
                        end
                        $display("");
                    end
                end
                    
                //***********************
                // Show the output image
                //***********************
                $display("\033[1;34m");
                $display("Your image:");
                $display("\033[1;0m");
                for( m=0 ; m<SE_SIZE ; m=m+1 ) begin
                    for ( n=0 ; n<SE_SIZE ; n=n+1 ) begin
                        if ( m==0 && n==0 ) $write("\033[1;31m");
                        else                $write("\033[1;0m");
                        $write("%d", your[i+m][j+n]);
                    end
                    $display("");
                end
                
                //*********************
                // Show the Gold image
                //*********************
                $display("\033[1;34m");
                $display("Gold image:");
                $display("\033[1;0m");
                for( m=0 ; m<SE_SIZE ; m=m+1 ) begin
                    for ( n=0 ; n<SE_SIZE ; n=n+1 ) begin
                        if ( m==0 && n==0 ) $write("\033[1;31m");
                        else                $write("\033[1;0m");
                        $write("%d", gold[i+m][j+n]);
                    end
                    $display("");
                end
                
                $display("\033[1;0m");
                repeat (5) @(negedge clk);
                $finish;
            end
        end
    end
    tot_lat = tot_lat + exe_lat;

    change_dram_task;
end endtask

//**************************************
//      Dump Task
//**************************************
integer dump_i, dump_j;
task dump_ans_task; begin
    //====
    file_out = $fopen("ORIGINAL_PIC_SE.txt", "w");
    // PIC
    $fwrite(file_out, "ORIGINAL PIC IMAGE #%-d\n\n", pat);
    // row index
    $fwrite(file_out, "_____");
    for ( dump_i=0 ; dump_i<PIC_SIZE ; dump_i=dump_i+1 ) $fwrite(file_out, "%3d|", dump_i);
    $fwrite(file_out, "\n");
    // image
    for ( dump_i=0 ; dump_i<PIC_SIZE ; dump_i=dump_i+1 ) begin
        $fwrite(file_out, "%3d| ", dump_i);
        for ( dump_j=0 ; dump_j<PIC_SIZE ; dump_j=dump_j+1 ) begin
            $fwrite(file_out, "%3d|", A[dump_i][dump_j]);
        end
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");

    // SE
    $fwrite(file_out, "ORIGINAL SE IMAGE #%-d\n\n", pat);
    for ( dump_i=0 ; dump_i<SE_SIZE ; dump_i=dump_i+1 ) begin
        for ( dump_j=0 ; dump_j<SE_SIZE ; dump_j=dump_j+1 ) begin
            $fwrite(file_out, "%3d ", B[dump_i][dump_j]);
        end
        $fwrite(file_out, "\n\n");
    end
    $fclose(file_out);

    //====
    if(mode==2) begin
        file_out = $fopen("HISTOGRAM.txt", "w");
        $fwrite(file_out, "CDF table #%-d :\n\n", pat);
        $fwrite(file_out, "=================\n");
        $fwrite(file_out, "| Value | Count |\n");
        for ( m=0 ; m<256 ; m=m+1 ) begin
            if ( cdf[m] != 0 )
                $fwrite(file_out, "|  %4d |  %4d |\n", m, cdf[m]);
        end
        $fwrite(file_out, "=================\n");
        $fclose(file_out);
    end

    //====
    file_out = $fopen("YOUR_PIC.txt", "w");
    $fwrite(file_out, "YOUR PIC IMAGE #%-d\n\n", pat);
    // row index
    $fwrite(file_out, "_____");
    for ( dump_i=0 ; dump_i<PIC_SIZE ; dump_i=dump_i+1 ) $fwrite(file_out, "%3d|", dump_i);
    $fwrite(file_out, "\n");
    // image
    for ( dump_i=0 ; dump_i<PIC_SIZE ; dump_i=dump_i+1 ) begin
        $fwrite(file_out, "%3d| ", dump_i);
        for ( dump_j=0 ; dump_j<PIC_SIZE ; dump_j=dump_j+1 ) begin
            $fwrite(file_out, "%3d|", your[dump_i][dump_j]);
        end
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");
    $fclose(file_out);

    //====
    file_out = $fopen("GOLDEN_PIC.txt", "w");
    $fwrite(file_out, "GOLD PIC IMAGE #%-d\n\n", pat);
    // row index
    $fwrite(file_out, "_____");
    for ( dump_i=0 ; dump_i<PIC_SIZE ; dump_i=dump_i+1 ) $fwrite(file_out, "%3d|", dump_i);
    $fwrite(file_out, "\n");
    // image
    for ( dump_i=0 ; dump_i<PIC_SIZE ; dump_i=dump_i+1 ) begin
        $fwrite(file_out, "%3d| ", dump_i);
        for ( dump_j=0 ; dump_j<PIC_SIZE ; dump_j=dump_j+1 ) begin
            $fwrite(file_out, "%3d|", gold[dump_i][dump_j]);
        end
        $fwrite(file_out, "\n");
    end
    $fwrite(file_out, "\n");
    $fclose(file_out);
end endtask

//**************************************
//      Pass Task
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
