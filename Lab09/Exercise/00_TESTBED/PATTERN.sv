`include "../00_TESTBED/pseudo_DRAM.sv"
`include "Usertype_FD.sv"
`include "../00_TESTBED/fd_dm.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;

//================================================================
//      PARAMETERS FOR PATTERN CONTROL
//================================================================
parameter OUT_NUM      = 1;
parameter PATNUM       = 1;
parameter ID_NUM       = 256;
parameter CTM_FOOD_MAX = 16;
parameter RES_ORD_MAX  = 256;
parameter RES_FOOD_MAX = 256;
integer   SEED         = 122;

//================================================================
//      Data Model
//================================================================
// Calculation manager
uberMgr m_uber = new();
// Input data set
typedef enum {dId, act, ctm, rId, food} giveFlag;
Delivery_man_id  cur_dman_id;
Action           cur_action;
Ctm_Info         cur_ctm_info;
Restaurant_id    cur_res_id;
food_ID_servings cur_serv_food;

Delivery_man_id  old_dman_id;
Action           old_action;
Ctm_Info         old_ctm_info;
Restaurant_id    old_res_id;
food_ID_servings old_serv_food;


/*
    1. record the current info
    2. execute action
    3. get the current info
*/

//================================================================
//      PARAMETERS & VARIABLES
//================================================================
parameter DELAY     = 1200;

integer         i;
integer         j;
integer         m;
integer         n;

integer       pat;
integer      size;

integer total_lat;
integer   exe_lat;
integer   out_lat;

//pragma protect
//pragma protect begin

//================================================================
//      CLASS RANDOM
//================================================================
class dManId_R;
    rand Delivery_man_id r_dman_id;
    function new ( int seed );
        this.srandom(seed);
    endfunction
    constraint range{
        r_dman_id inside { [0:ID_NUM-1] };
    }
endclass

class action_R;
    rand Action r_act;
    function new ( int seed );
        this.srandom(seed);
    endfunction 
    constraint range{
        r_act inside { Take, Deliver, Order, Cancel };
    }
endclass

class ctmInfo_R;
    rand Ctm_Info r_ctm_info;
    function new ( int seed );
        this.srandom(seed);
    endfunction 
    constraint range{
        r_ctm_info.ctm_status inside { Normal, VIP };
        r_ctm_info.res_ID     inside { [0:ID_NUM-1] };
        r_ctm_info.food_ID    inside { FOOD1, FOOD2, FOOD3 };
        r_ctm_info.ser_food   inside { [1:CTM_FOOD_MAX-1] };
    }
endclass

class resId_R;
    rand Restaurant_id r_res_id;
    function new ( int seed );
        this.srandom(seed);
    endfunction
    constraint range{
        r_res_id inside { [0:ID_NUM-1] };
    }
endclass

class servFood_R;
    rand food_ID_servings r_serv_food;
    function new ( int seed );
        this.srandom(seed);
    endfunction
    constraint range{
        r_serv_food.d_food_ID  inside { FOOD1, FOOD2, FOOD3 };
        r_serv_food.d_ser_food inside { [1:15] };
    }
endclass

task action_task; begin
    // Random Class
    action_R randAct = new(SEED);

    // Valid
    inf.act_valid = 1'b1;
    void'(randAct.randomize());
    old_action = cur_action;
    cur_action = Take;//randAct.r_act;
end endtask

task dManId_task; begin
    // Random Class
    dManId_R randDId = new(SEED);

    // Valid
    inf.id_valid = 1'b1;
    void'(randDId.randomize());
    old_dman_id = cur_dman_id;
    cur_dman_id = randDId.r_dman_id;
end endtask

task ctmInfo_task; begin
    // Random Class
    ctmInfo_R randCtm = new(SEED);

    // Valid
    inf.cus_valid = 1'b1;
    void'(randCtm.randomize());
    old_ctm_info = cur_ctm_info;
    cur_ctm_info = randCtm.r_ctm_info;
end endtask

task resId_task; begin
    // Random Class
    resId_R randId = new(SEED);

    // Valid
    inf.res_valid = 1'b1;
    void'(randId.randomize());
    old_res_id = cur_res_id;
    cur_res_id = randId.r_res_id;
end endtask

task servFood_task;
    input Action act_in;
begin
    // Random Class
    servFood_R randFood = new(SEED);

    // Valid
    inf.food_valid = 1'b1;
    void'(randFood.randomize());
    old_serv_food = cur_serv_food;
    // When canceling food, PATTERN don't need to give the serving food num
    if(act_in == Cancel) randFood.r_serv_food.d_ser_food = 0;
    cur_serv_food = randFood.r_serv_food;
end endtask

task showAction_task; begin
    $display("\033[1;44m==============================\033[0m");
    $display("\033[1;44m=        Action Info         =\033[0m");
    $display("\033[1;44m==============================\033[0m");
    $display("----------------------------------------------------------------");
    $display("[Action] : [%10s]", cur_action.name());
    $display("----------------------------------------------------------------");
    if(cur_action == Take) begin
        $display(" [D Man Id] | ------------ : [0x%8h] ", cur_dman_id);
        $display(" [Ctm Info] | [Ctm Status] : [%10s]",  cur_ctm_info.ctm_status.name());
        $display("            | [    Res Id] : [0x%8h]", cur_ctm_info.res_ID);
        $display("            | [ Food Type] : [%10s]",  cur_ctm_info.food_ID.name());
        $display("            | [ Serv Food] : [%10d]",  cur_ctm_info.ser_food);
    end
    else if(cur_action == Deliver) begin
        $display(" [D Man Id] : [0x%8h] ", cur_dman_id);
    end
    else if(cur_action == Order) begin
        $display(" [       Res Id] | ----------- : [0x%8h] ", cur_res_id);
        $display(" [Food Id & Ser] | [Food Type] : [%10s] ", cur_serv_food.d_food_ID.name());
        $display("                 | [Serv Food] : [%10d] ", cur_serv_food.d_ser_food);
    end
    else if(cur_action == Cancel) begin
        $display(" [     D Man Id] | ----------- : [0x%8h] ", cur_dman_id);
        $display(" [       Res Id] | ----------- : [0x%8h] ", cur_res_id);
        $display(" [Food Id & Ser] | [Food Type] : [%10s]",   cur_ctm_info.food_ID.name());
    end
    $display("----------------------------------------------------------------\n");
end endtask

//======================================
//              MAIN
//======================================
initial exe_task;

//======================================
//              TASKS
//======================================
//***************************
//      Execution Task
//***************************
task exe_task; begin
    reset_task;
    for ( pat=0 ; pat<PATNUM ; pat=pat+1 ) begin
        input_task;
        cal_task;
        wait_task;
        check_task;
        $display("\033[32mNo.%-5d PATTERN PASS!!! \033[1;34mLatency : %-5d\033[1;0m", pat, exe_lat);
    end
    pass_task;
end endtask

//***************************
//      Reset Task
//***************************
task reset_task; begin
    inf.rst_n      = 1;
    inf.id_valid   = 0;
    inf.act_valid  = 0;
    inf.cus_valid  = 0;
    inf.res_valid  = 0;
    inf.food_valid = 0;
    inf.D          = 'dx;
    total_lat      = 0;

    // Reset data model

    #(10) inf.rst_n = 0;
    #(10) inf.rst_n = 1;
    if ( inf.out_valid !== 0 || inf.complete !== 0 || inf.err_msg !== 0 || inf.out_info !== 0 ) begin
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
        repeat(5) #(10);
        $finish;
    end
end endtask

//***************************
//      Input Task
//***************************
task give_DATA_task;
    input giveFlag flag_in;
begin
    inf.D = 0;
    if(flag_in == dId) begin
        
        inf.D = cur_dman_id;
        @(negedge clk);
        inf.id_valid = 1'b0;
    end
    else if(flag_in == act) begin
        inf.D = cur_action;
        @(negedge clk);
        inf.act_valid = 1'b0;
    end
    else if(flag_in == ctm) begin
        inf.D = cur_ctm_info;
        @(negedge clk);
        inf.cus_valid = 1'b0;
    end
    else if(flag_in == rId) begin
        inf.D = cur_res_id;
        @(negedge clk);
        inf.res_valid = 1'b0;
    end
    else if(flag_in == food) begin
        inf.D = cur_serv_food;
        @(negedge clk);
        inf.food_valid = 1'b0;
    end
    inf.D = 'dx;
end endtask

task input_task; begin
    repeat( ({$random(SEED)} % 9 + 2) ) @(negedge clk);
    //---------
    // Action
    //---------
    action_task;
    cur_action = Deliver;
    give_DATA_task(act);
    repeat( ({$random(SEED)} % 5 + 1) ) @(negedge clk);
    
    //---------
    // Take
    //---------
    if(cur_action == Take) begin
        if((old_action==Take && ({$random(SEED)} % 2) == 0) || old_action!==Take || pat==0) begin
            dManId_task;
            give_DATA_task(dId);
            repeat( ({$random(SEED)} % 5 + 1) ) @(negedge clk);
        end
        ctmInfo_task;
        give_DATA_task(ctm);
    end
    //---------
    // Deliver
    //---------
    else if(cur_action == Deliver) begin
        dManId_task;
        give_DATA_task(dId);
    end
    //---------
    // Order
    //---------
    else if(cur_action == Order) begin
        if((old_action==Order && ({$random(SEED)} % 2) == 0) || old_action!==Order || pat==0) begin
            resId_task;
            give_DATA_task(rId);
            repeat( ({$random(SEED)} % 5 + 1) ) @(negedge clk);
        end
        servFood_task(Order);
        give_DATA_task(food);
    end
    //---------
    // Cancel
    //---------
    else if(cur_action == Cancel) begin
        resId_task;
        give_DATA_task(rId);
        repeat( ({$random(SEED)} % 5 + 1) ) @(negedge clk);
        servFood_task(Cancel);
        give_DATA_task(food);
        repeat( ({$random(SEED)} % 5 + 1) ) @(negedge clk);
        dManId_task;
        give_DATA_task(dId);
    end
end endtask

//***************************
//      Calculation Task
//***************************
task cal_task; begin
    void'(m_uber.setAction(cur_action));
    if(cur_action == Take)         void'(m_uber.take   (cur_dman_id, cur_ctm_info));
    else if(cur_action == Deliver) void'(m_uber.deliver(cur_dman_id));
    else if(cur_action == Order)   void'(m_uber.order  (cur_res_id, cur_serv_food));
    else if(cur_action == Cancel)  void'(m_uber.cancel (cur_res_id, cur_serv_food.d_food_ID, cur_dman_id));
end endtask

//***************************
//      Wait Task
//***************************
task wait_task; begin
    exe_lat = -1;
    while ( inf.out_valid !== 1 ) begin
        if (exe_lat == DELAY) begin
            $display("                                   ..--.                                ");
            $display("                                `:/:-:::/-                              ");
            $display("                                `/:-------o                             ");
            $display("                                /-------:o:                             ");
            $display("                                +-:////+s/::--..                        ");
            $display("    The execution latency      .o+/:::::----::::/:-.       at %-12d ps  ", $time*1000);
            $display("    is over 5000 cycles       `:::--:/++:----------::/:.                ");
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

//***************************
//      Check Task
//***************************
task check_task; begin
    out_lat = 0;
    i = 0;
    while ( inf.out_valid === 1 ) begin
        if (out_lat==OUT_NUM) begin
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

        if ( out_lat<OUT_NUM ) begin
            void'(m_uber.setYour(inf.complete, inf.err_msg, inf.out_info));
        end
       
        out_lat = out_lat + 1;
        @(negedge clk);
    end

    if (out_lat<OUT_NUM) begin
        $display("                                                                                ");   
        $display("                                                   ./+oo+/.                     ");   
        $display("    Out cycles is less than 1                     /s:-----+s`     at %-12d ps   ",$time*1000);   
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
    if(m_uber.check() === 0) begin
        showAction_task;
        $display("\033[1;1m\033[1;31m[ Fail! Stop Running! ]\033[1;0m");
        $display("\033[1;1m\033[1;31m[ Debug info is shown above! ]\033[1;0m");
        repeat(5) @(negedge clk);
        $finish;
    end
    total_lat = total_lat + exe_lat;
end endtask

task pass_task; begin
    $display("\033[1;33m                `oo+oy+`                            \033[1;35m Congratulation!!! \033[1;0m                                   ");
    $display("\033[1;33m               /h/----+y        `+++++:             \033[1;35m PASS This Lab........Maybe \033[1;0m                          ");
    $display("\033[1;33m             .y------:m/+ydoo+:y:---:+o                                                                                      ");
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
    $display("=======================================================================================================================================");
    $display("Total Latency : %-1d", total_lat);
    $display("=======================================================================================================================================");

    repeat (5) @(negedge clk);
    $finish;
end endtask

endprogram

//pragma protect end
