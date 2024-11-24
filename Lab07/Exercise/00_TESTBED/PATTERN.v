`ifdef RTL
    `timescale 1ns/1ps
    `include "CDC.v"
    `define CYCLE_TIME_clk1 36.7
    `define CYCLE_TIME_clk2 6.8
    `define CYCLE_TIME_clk3 2.6
`endif
`ifdef GATE
    `timescale 1ns/1ps
    `include "CDC_SYN.v"
    `define CYCLE_TIME_clk1 36.7
    `define CYCLE_TIME_clk2 6.8
    `define CYCLE_TIME_clk3 2.6
`endif

// TODO :
// check winner + calculate winner

module PATTERN(
    //Output Port
    clk1,
    clk2,
    clk3,
    rst_n,
    in_valid1,
    in_valid2,
    user1,
    user2,

    //Input Port
    out_valid1,
    out_valid2,
    equal,
    exceed,
    winner
); 
//======================================
//          I/O PORTS
//======================================
output reg       clk1;
output reg       clk2;
output reg       clk3;
output reg       rst_n;
output reg       in_valid1;
output reg       in_valid2;
output reg [3:0] user1;
output reg [3:0] user2;

input            out_valid1;
input            out_valid2;
input            equal;
input            exceed;
input            winner;

//======================================
//      PARAMETERS & VARIABLES
//======================================
parameter PATNUM = 1;
parameter CYCLE1 = `CYCLE_TIME_clk1;
parameter CYCLE2 = `CYCLE_TIME_clk2;
parameter CYCLE3 = `CYCLE_TIME_clk3;
parameter DELAY  = 100000;
integer   SEED   = 122;

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
parameter IN_NUM       = 5;
parameter USER_OUT_NUM = 7;
parameter WIN_NUM      = 2;
parameter USER_NUM     = 2;
parameter CARD_SUM_MAX = 21;
parameter CARD_MAX     = 10;
integer   out_user_pat;                                    // record the current pattern for user(out_valid1)
integer   out_win_pat;                                     // record the current pattern for winner(out_valid2)
integer   out_iter;                                        // record the current iteration
integer   out_finish_user_flag;                            // show that the last pat is finished for user
integer   out_finish_win_flag;                             // show that the last pat is finished for winner
integer   user1_check;                                     // check the sent data of user1
integer   user2_check;                                     // check the sent data of user1
integer   win_check;                                       // check the winner
integer   hand[1:USER_NUM][0:PATNUM-1][1:IN_NUM];          // user * epoch * (card/epoch)
integer   gold_equal[1:USER_NUM][0:PATNUM-1][3:IN_NUM-1];  // user * epoch * (card/epoch)
integer   gold_exceed[1:USER_NUM][0:PATNUM-1][3:IN_NUM-1]; // user * epoch * (card/epoch)
integer   gold_win[0:PATNUM-1];                            // user * epoch * (card/epoch)
integer   gold_card[0:PATNUM-1][0:3][1:13];

integer   your_equal[1:USER_NUM][0:PATNUM-1][3:IN_NUM-1];  // user * epoch * (card/epoch)
integer   your_exceed[1:USER_NUM][0:PATNUM-1][3:IN_NUM-1]; // user * epoch * (card/epoch)
integer   your_win[0:PATNUM-1];                            // user * epoch * (card/epoch)


//======================================
//      POKER CARD MODEL
//======================================
parameter NO_CARD = 0;
integer card[0:3][1:13]; // four suits * points

integer suit_idx;
integer pt_idx;
integer card_idx;

// reset the card deck
task reset_card; begin
    for(suit_idx=0 ; suit_idx<4 ; suit_idx=suit_idx+1) begin
        for(pt_idx=1 ; pt_idx<=13 ; pt_idx=pt_idx+1) begin
            card[suit_idx][pt_idx] = 1;
        end
    end
end endtask

// get the remain card deck
task get_remain_card;
    output integer card_num;
begin
    card_num = 0;
    for(suit_idx=0 ; suit_idx<4 ; suit_idx=suit_idx+1) begin
        for(pt_idx=1 ; pt_idx<=13 ; pt_idx=pt_idx+1) begin
            if(card[suit_idx][pt_idx] == 1) card_num = card_num + 1;
        end
    end
end endtask

// get the remain card deck of the specific point
task get_pt_remain_card;
    input integer pt_in;
    output integer card_num;
begin
    card_num = 0;
    for(suit_idx=0 ; suit_idx<4 ; suit_idx=suit_idx+1) begin
        if(card[suit_idx][pt_in] == 1) card_num = card_num + 1;
    end
end endtask

// deal the card
integer flag_tmp;
integer rand_tmp;
integer check_tmp;
task deal_card;
    output integer card_out;
begin
    flag_tmp = 0;
    while(flag_tmp != 1) begin
        rand_tmp = {$random(SEED)}%13 + 1;
        if(card[0][rand_tmp]) begin
            flag_tmp = 1;
            card_out = rand_tmp;
            card[0][rand_tmp] = 0;
        end
        else if(card[1][rand_tmp]) begin
            flag_tmp = 1;
            card_out = rand_tmp;
            card[1][rand_tmp] = 0;
        end
        else if(card[2][rand_tmp]) begin
            flag_tmp = 1;
            card_out = rand_tmp;
            card[2][rand_tmp] = 0;
        end
        else if(card[3][rand_tmp]) begin
            flag_tmp = 1;
            card_out = rand_tmp;
            card[3][rand_tmp] = 0;
        end
    end
end endtask

// set the gold card deck
task set_gold_card;
    input integer pat_in;
begin
    for(suit_idx=0 ; suit_idx<4 ; suit_idx=suit_idx+1) begin
        for(pt_idx=1 ; pt_idx<=13 ; pt_idx=pt_idx+1) begin
            gold_card[pat_in][suit_idx][pt_idx] = card[suit_idx][pt_idx];
        end
    end
end endtask

// show the total card deck
task show_card; begin
    $write("\033[1;34m");
    $display("==========================================");
    $display("=           Current CARD DECK            =");
    $display("==========================================");
    $write("   ");
    for(pt_idx=1 ; pt_idx<=13 ; pt_idx=pt_idx+1) $write("%2d ", pt_idx);
    $write("\n");
    $write("\033[1;0m");
    for(suit_idx=0 ; suit_idx<4 ; suit_idx=suit_idx+1) begin
        $write("\033[1;34m");
        $write("%2d ", suit_idx);
        $write("\033[1;0m");
        for(pt_idx=1 ; pt_idx<=13 ; pt_idx=pt_idx+1) begin
            if(card[suit_idx][pt_idx] == 1) $write("\033[1;32m V \033[1;0m");
            else $write("\033[1;31m - \033[1;0m");
        end
        $write("\n");
    end
    $write("\n");
end endtask

// show the total gold card deck
task show_gold_card;
    input integer pat_in;
begin
    $write("\033[1;34m");
    $display("==========================================");
    $display("=        Current GOLD CARD DECK          =");
    $display("==========================================");
    $write("   ");
    for(pt_idx=1 ; pt_idx<=13 ; pt_idx=pt_idx+1) $write("%2d ", pt_idx);
    $write("\n");
    $write("\033[1;0m");
    for(suit_idx=0 ; suit_idx<4 ; suit_idx=suit_idx+1) begin
        $write("\033[1;34m");
        $write("%2d ", suit_idx);
        $write("\033[1;0m");
        for(pt_idx=1 ; pt_idx<=13 ; pt_idx=pt_idx+1) begin
            if(gold_card[pat_in][suit_idx][pt_idx] == 1) $write("\033[1;32m V \033[1;0m");
            else $write("\033[1;31m - \033[1;0m");
        end
        $write("\n");
    end
    $write("\n");
end endtask

//======================================
//      USER MODEL
//======================================
integer hand_idx;
integer hand_pt_idx;

// Get the equal probability
integer equal_tmp;
integer hand_pt_tmp;
integer d_acc_tmp;
integer d_prob_1;
integer n_prob_1;
task get_equal_prob;
    input integer user_sel;
    input integer iter; // 3 -> 4
    input integer pat_in;
    output integer prob;
begin
    equal_tmp = 0;
    get_iter_hand(user_sel, iter, pat_in, equal_tmp);
    equal_tmp = CARD_SUM_MAX - equal_tmp;
    if(equal_tmp <= 0 ) prob = 0;
    else if(equal_tmp > CARD_MAX) prob = 0;
    else begin
        if(equal_tmp !== 1) get_pt_remain_card(equal_tmp, d_prob_1);
        else begin
            d_prob_1 = 0;
            get_pt_remain_card(1,  d_acc_tmp);
            d_prob_1 = d_prob_1 + d_acc_tmp;
            get_pt_remain_card(11, d_acc_tmp);
            d_prob_1 = d_prob_1 + d_acc_tmp;
            get_pt_remain_card(12, d_acc_tmp);
            d_prob_1 = d_prob_1 + d_acc_tmp;
            get_pt_remain_card(13, d_acc_tmp);
            d_prob_1 = d_prob_1 + d_acc_tmp;
        end
        get_remain_card(n_prob_1);
        prob = d_prob_1*'d100/n_prob_1;
    end
    // $display("[ Equal ]");
    // $display("The equal pt : %-2d", equal_tmp);
    // $display("Den : %-2d, Num : %-2d", d_prob_1, n_prob_1);
    // $display("Prob : %-2d", prob);
end endtask

// Get the exceed probability
integer start_tmp;
integer acc_idx;
integer acc_tmp;
integer d_prob_2;
integer n_prob_2;
task get_exceed_prob;
    input integer user_sel;
    input integer iter; // 3 -> 4
    input integer pat_in;
    output integer prob;
begin
    start_tmp = 0;
    get_iter_hand(user_sel, iter, pat_in, start_tmp);
    start_tmp = CARD_SUM_MAX - start_tmp + 1;
    if(start_tmp <= 1) begin
        prob = 100;
    end
    else if(start_tmp > CARD_MAX) begin
        prob = 0;
    end
    else begin
        d_prob_2 = 0;
        acc_tmp = 0;
        for(acc_idx=start_tmp ; acc_idx<=CARD_MAX ; acc_idx=acc_idx+1) begin
            get_pt_remain_card(acc_idx, acc_tmp);
            d_prob_2 = d_prob_2 + acc_tmp;
        end
        get_remain_card(n_prob_2);
        prob = d_prob_2*'d100/n_prob_2;
    end
    // $display("[ Exceed ]");
    // $display("start : %-1d", start_tmp);
    // $display("Den : %-2d, Num : %-2d", d_prob_2, n_prob_2);
    // $display("Prob : %-2d", prob);
end endtask

// Get the specific iteration of hand card
task get_iter_hand;
    input integer user_sel;
    input integer iter; // 3 -> 4
    input integer pat_in;
    output integer out_pt;
begin
    out_pt = 0;
    for(hand_idx=1 ; hand_idx<=iter ; hand_idx=hand_idx+1) begin
        if(hand[user_sel][pat_in][hand_idx] >= 11)
            out_pt = out_pt + 1;
        else
            out_pt = out_pt + hand[user_sel][pat_in][hand_idx];
    end
end endtask

// show the hand fo two users
task show_user;
    input integer pat_in;
begin
    $write("\033[1;34m");
    $display("==========================================");
    $display("=             USER HAND                  =");
    $display("==========================================");
    $write("PAT#%-6d User 1 : { ", pat_in);
    for(hand_idx=1 ; hand_idx<=IN_NUM ; hand_idx=hand_idx+1) $write("\033[1;33m %-2d \033[1;34m", hand[1][pat_in][hand_idx]);
    $write("}\n");

    $write("PAT#%-6d User 2 : { ", pat_in);
    for(hand_idx=1 ; hand_idx<=IN_NUM ; hand_idx=hand_idx+1) $write("\033[1;33m %-2d \033[1;34m", hand[2][pat_in][hand_idx]);
    $write("}\n\n");
    $write("\033[1;0m");
end endtask

//======================================
//              CLOCK
//======================================
initial clk1 = 0;
always #(CYCLE1/2.0) clk1 = ~clk1;

initial clk2 = 0;
always #(CYCLE2/2.0) clk2 = ~clk2;

initial clk3 = 0;
always #(CYCLE3/2.0) clk3 = ~clk3;

//======================================
//              MAIN
//======================================
initial exe_task;

//======================================
//              TASKS
//======================================
task exe_task; begin
    reset_task;
    fork
        input_task;
        wait_task;
        check_task;
    join
    // $display("\033[0;34mPASS PATTERN NO.%4d,\033[m \033[0;32m Cycles: %3d\033[m", pat ,exe_lat);
    pass_task;
end endtask

//**************************************
//      Reset Task
//**************************************
task reset_task; begin
    force clk1 = 0;
    force clk2 = 0;
    force clk3 = 0;
    rst_n      = 1;
    in_valid1  = 'd0;
    in_valid2  = 'd0;
    user1      = 'dx;
    user2      = 'dx;

    tot_lat = 0;

    #(CYCLE1/2.0) rst_n = 0;
    #(CYCLE1/2.0) rst_n = 1;
    if (out_valid1 !== 0 || out_valid2 !== 0 || equal !== 0 || exceed !== 0 || winner !== 0) begin
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
        repeat(5) #(CYCLE1);
        $finish;
    end
    #(CYCLE1/2.0);

    release clk1;
    release clk2;
    release clk3;

end endtask

//**************************************
//      Input Task
//**************************************
integer input_card_tmp;
integer output_card_tmp;
integer output_card_tmp_1;
integer output_card_tmp_2;
task input_task; begin
    for (pat=0 ; pat<PATNUM ; pat=pat+1) begin
        // Every 5 epoch reset the card deck
        if(pat%5 == 0) reset_card;
        // show_card;

        //-----------------------
        //  Deal card to user
        //-----------------------
        // user 1
        for(i=1 ; i<=IN_NUM ; i=i+1) begin
            deal_card(input_card_tmp);
            hand[1][pat][i] = input_card_tmp;
            // Calculate the probability
            if(i>=3 && i<=4) begin
                // show_card;
                // show_user(pat);
                get_equal_prob(1, i, pat, output_card_tmp_1);
                gold_equal[1][pat][i] = output_card_tmp_1;
                get_exceed_prob(1, i, pat, output_card_tmp_1);
                gold_exceed[1][pat][i] = output_card_tmp_1;
            end
        end
        // user 2
        for(i=1 ; i<=IN_NUM ; i=i+1) begin
            deal_card(input_card_tmp);
            hand[2][pat][i] = input_card_tmp;
            // Calculate the probability
            if(i>=3 && i<=4) begin
                // show_card;
                // show_user(pat);
                get_equal_prob(2, i, pat, output_card_tmp_2);
                gold_equal[2][pat][i] = output_card_tmp_2;
                get_exceed_prob(2, i, pat, output_card_tmp_2);
                gold_exceed[2][pat][i] = output_card_tmp_2;
            end
        end
        // Card deck
        set_gold_card(pat);
        // show_card;
        // show_user(pat);

        get_iter_hand(1, 5, pat, output_card_tmp_1);
        // $display("$$$$$ : %-d", output_card_tmp_1);
        get_iter_hand(2, 5, pat, output_card_tmp_2);
        // $display("$$$$$ : %-d", output_card_tmp_2);
        if(output_card_tmp_1 <= CARD_SUM_MAX && output_card_tmp_2 <= CARD_SUM_MAX) begin
            if(output_card_tmp_1 == output_card_tmp_2) gold_win[pat] = 0;
            else if(output_card_tmp_1 > output_card_tmp_2) gold_win[pat] = 1;
            else if(output_card_tmp_1 < output_card_tmp_2) gold_win[pat] = 2;
        end
        else if(output_card_tmp_1 > CARD_SUM_MAX && output_card_tmp_2 > CARD_SUM_MAX)
            gold_win[pat] = 0;
        else if(output_card_tmp_1 > CARD_SUM_MAX)
            gold_win[pat] = 2;
        else if(output_card_tmp_2 > CARD_SUM_MAX)
            gold_win[pat] = 1;

        // $display("$$$$$ : %-d", gold_win[pat]);

        //-------------
        //  Send data
        //-------------
        // user 1
        for(i=1 ; i<=IN_NUM ; i=i+1) begin
            in_valid1  = 'd1;
            user1      = hand[1][pat][i];
            @(negedge clk1);
        end
        in_valid1  = 'd0;
        user1      = 'dx;
        // user 2
        for(i=1 ; i<=IN_NUM ; i=i+1) begin
            in_valid2  = 'd1;
            user2      = hand[2][pat][i];
            @(negedge clk1);
        end
        in_valid2  = 'd0;
        user2      = 'dx;
    end
end endtask

//**************************************
//      Wait Task
//**************************************
integer aaa = 0;
task wait_task; begin
    exe_lat = -1;
    wait(in_valid1);
    while (out_finish_user_flag !== 1 || out_finish_win_flag !== 1) begin
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
            repeat(5) @(negedge clk3);
            $finish; 
        end
        exe_lat = exe_lat + 1;
        @(negedge clk3);
    end
end endtask

//**************************************
//      Check Task
//**************************************
reg[6:0] get_eq;
reg[6:0] get_ex;
integer err_user_flag;
integer err_win_flag;
integer user1_lock;
task check_task; begin
    out_user_pat         = 0;
    out_win_pat          = 0;
    out_iter             = 3;
    out_finish_user_flag = 0;
    out_finish_win_flag  = 0;
    user1_check          = 0;
    user2_check          = 0;
    win_check            = 0;
    err_user_flag        = 0;
    err_win_flag         = 0;
    user1_lock           = 0;

    out_lat = 0;
    while(out_finish_user_flag == 0 || out_finish_win_flag == 0) begin
        wait(out_valid1 || out_valid2);
        @(negedge clk3);

        // Get the output data
        if(out_valid1) begin
            if(user1_check == 0) begin
                // Get the user1 data
                while(out_valid1) begin
                    if (out_lat == USER_OUT_NUM) begin
                        $display("=======================================");
                        $display("=        (winnie the pooh.jpg)        =");
                        $display("= User1 out cycles is more than %-2d  =", USER_OUT_NUM);
                        $display("=        at at %-12d ps               =", $time*1000);
                        $display("=======================================");
                        repeat(5) @(negedge clk3);
                        $finish;
                    end
                    get_eq[USER_OUT_NUM-out_lat-1] = equal;
                    get_ex[USER_OUT_NUM-out_lat-1] = exceed;
                    out_lat = out_lat + 1;
                    @(negedge clk3);
                end
                your_equal[1][out_user_pat][out_iter] = get_eq;
                your_exceed[1][out_user_pat][out_iter] = get_ex;

                // Check the user1 data
                if(gold_equal[1][out_user_pat][out_iter] !== your_equal[1][out_user_pat][out_iter]) begin
                    err_user_flag = 1;
                    $write("\033[1;34m");
                    $display("=======================================");
                    $display("=        (winnie the pooh.jpg)        =");
                    $display("= User 1 equal signal is not correct  =");
                    $display("=======================================");
                    $display("Error PAT  : %-6d", out_user_pat);
                    $display("Error Hand : %-6d", out_iter);
                    $display("Your       : \033[1;33m %-3d \033[1;34m", your_equal[1][out_user_pat][out_iter]);
                    $display("Gold       : \033[1;33m %-3d \033[1;0m", gold_equal[1][out_user_pat][out_iter]);
                    $write("\033[1;0m\n");
                end
                if(gold_exceed[1][out_user_pat][out_iter] !== your_exceed[1][out_user_pat][out_iter]) begin
                    err_user_flag = 1;
                    $write("\033[1;34m");
                    $display("=======================================");
                    $display("=        (winnie the pooh.jpg)        =");
                    $display("= User 1 exceed signal is not correct =");
                    $display("=======================================");
                    $display("Error PAT  : %-6d", out_user_pat);
                    $display("Error Hand : %-6d", out_iter);
                    $display("Your       : \033[1;33m %-3d \033[1;34m", your_exceed[1][out_user_pat][out_iter]);
                    $display("Gold       : \033[1;33m %-3d \033[1;0m", gold_exceed[1][out_user_pat][out_iter]);
                    $write("\033[1;0m\n");
                end
                out_lat = 0;
                user1_check = 1;
            end
            else if(user2_check == 0) begin
                // Get the user2 data
                while(out_valid1) begin
                    if (out_lat == USER_OUT_NUM) begin
                        $display("=======================================");
                        $display("=        (winnie the pooh.jpg)        =");
                        $display("= User2 out cycles is more than %-2d  =", USER_OUT_NUM);
                        $display("=        at at %-12d ps               =", $time*1000);
                        $display("=======================================");
                        repeat(5) @(negedge clk3);
                        $finish;
                    end
                    get_eq[USER_OUT_NUM-out_lat-1] = equal;
                    get_ex[USER_OUT_NUM-out_lat-1] = exceed;
                    out_lat = out_lat + 1;
                    @(negedge clk3);
                end
                your_equal[2][out_user_pat][out_iter] = get_eq;
                your_exceed[2][out_user_pat][out_iter] = get_ex;

                // Check the user2 data
                if(gold_equal[2][out_user_pat][out_iter] !== your_equal[2][out_user_pat][out_iter]) begin
                    err_user_flag = 1;
                    $write("\033[1;34m");
                    $display("=======================================");
                    $display("=        (winnie the pooh.jpg)        =");
                    $display("= User 2 equal signal is not correct  =");
                    $display("=======================================");
                    $display("Error PAT  : %-6d", out_user_pat);
                    $display("Error Hand : %-6d", out_iter);
                    $display("Your       : \033[1;33m %-3d \033[1;34m", your_equal[2][out_user_pat][out_iter]);
                    $display("Gold       : \033[1;33m %-3d \033[1;0m", gold_equal[2][out_user_pat][out_iter]);
                    $write("\033[1;0m\n");
                end
                if(gold_exceed[2][out_user_pat][out_iter] !== your_exceed[2][out_user_pat][out_iter]) begin
                    err_user_flag = 1;
                    $write("\033[1;34m");
                    $display("=======================================");
                    $display("=        (winnie the pooh.jpg)        =");
                    $display("= User 2 exceed signal is not correct =");
                    $display("=======================================");
                    $display("Error PAT  : %-6d", out_user_pat);
                    $display("Error Hand : %-6d", out_iter);
                    $display("Your       : \033[1;33m %-3d \033[1;34m", your_exceed[2][out_user_pat][out_iter]);
                    $display("Gold       : \033[1;33m %-3d \033[1;0m", gold_exceed[2][out_user_pat][out_iter]);
                    $write("\033[1;0m\n");
                end
                out_lat = 0;
                user2_check = 1;
            end
        end
        else if(out_valid2) begin
            if(win_check == 0) begin
                // Get the winner
                if(winner == 1) begin
                    while(out_valid2) begin
                        if (out_lat == WIN_NUM) begin
                            $display("=======================================");
                            $display("=        (winnie the pooh.jpg)        =");
                            $display("= Winner out cycles is more than %-2d =", USER_OUT_NUM);
                            $display("=        at at %-12d ps               =", $time*1000);
                            $display("=======================================");
                            repeat(5) @(negedge clk3);
                            $finish;
                        end
                        if(winner == 0) your_win[out_win_pat] = 1;
                        else if(winner == 1) your_win[out_win_pat] = 2;
                        out_lat = out_lat + 1;
                        @(negedge clk3);
                    end
                end
                else begin
                    while(out_valid2) begin
                        if (out_lat == 1) begin
                            $display("=======================================");
                            $display("=        (winnie the pooh.jpg)        =");
                            $display("= Winner out cycles is more than 1    =");
                            $display("=        at at %-12d ps               =", $time*1000);
                            $display("=======================================");
                            repeat(5) @(negedge clk3);
                            $finish;
                        end
                        your_win[out_win_pat] = 0;
                        out_lat = out_lat + 1;
                        @(negedge clk3);
                    end
                end

                // Check the winner
                if(gold_win[out_win_pat] !== your_win[out_win_pat]) begin
                    err_win_flag = 1;
                    $write("\033[1;34m");
                    $display("=======================================");
                    $display("=        (winnie the pooh.jpg)        =");
                    $display("=        Winner is not correct        =");
                    $display("=======================================");
                    $display("Error PAT  : %-6d", out_win_pat);
                    $display("Error Hand : %-6d", out_iter);
                    $display("Your       : \033[1;33m %-3d \033[1;34m", your_win[out_win_pat]);
                    $display("Gold       : \033[1;33m %-3d \033[1;34m", gold_win[out_win_pat]);
                    $display("0 -> Tie, 1 -> User1, 2 -> User2");
                    $write("\033[1;0m\n");
                end
                out_lat = 0;
                win_check = 1;
            end
        end

        if(err_user_flag || err_win_flag) begin
            if(err_user_flag) begin
                show_gold_card(out_user_pat);
                show_user(out_user_pat);
            end
            else begin
                show_gold_card(out_win_pat);
                show_user(out_win_pat);
            end
            repeat(5) @(negedge clk3);
            $finish;
        end

        // Set the finish flag
        if(user2_check == 1) begin
            // Change pat
            out_iter = out_iter + 1;
            user2_check = 0;

            if(out_iter == 5) begin
                if(out_user_pat == PATNUM-1) out_finish_user_flag = 1;
                else begin
                    out_iter = 3;
                    out_user_pat = out_user_pat + 1;
                    user1_check = 0;
                end
                user1_lock = 0;
            end
        end
        else if(user1_check == 1 && user1_lock == 0) begin
            // Change pat
            out_iter = out_iter + 1;
            user1_check = 0;

            if(out_iter == 5) begin
                out_iter = 3;
                user1_check = 1;
                user1_lock = 1;
            end
        end

        
        if(win_check == 1) begin
            // Change pat
            win_check = 0;

            if(out_win_pat == PATNUM) out_finish_win_flag = 1;
            else begin
                out_win_pat = out_win_pat + 1;
            end
        end
    end
end endtask

//**************************************
//      Pass Task
//**************************************
task pass_task; begin
    $display("\033[1;33m                `oo+oy+`                            \033[1;35m Congratulation!!! \033[1;0m                                   ");
    $display("\033[1;33m               /h/----+y        `+++++:             \033[1;35m PASS This Lab........Maybe \033[1;0m                          ");
    $display("\033[1;33m             .y------:m/+ydoo+:y:---:+o             \033[1;35m Total Latency : %-10d\033[1;0m                                ", exe_lat);
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
    repeat(5) @(negedge clk1);
    $finish;
end endtask

endmodule
