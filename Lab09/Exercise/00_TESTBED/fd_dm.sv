`include "Usertype_FD.sv"
import usertype::*;

parameter DRAM_OFFSET = 'h10000;
parameter USER_NUM    = 256;
parameter DRAM_p_r    = "../00_TESTBED/DRAM/dram.dat";

class dramData;
    logic [7:0] golden_DRAM[ (DRAM_OFFSET+0) : ((DRAM_OFFSET+USER_NUM*8)-1) ];

    function new();
        $readmemh( DRAM_p_r, golden_DRAM );
    endfunction

    function res_info get_res(Restaurant_id r_id);
        res_info r_out;
        r_out.limit_num_orders = this.golden_DRAM[ (DRAM_OFFSET+r_id*8)   ];
        r_out.ser_FOOD1        = this.golden_DRAM[ (DRAM_OFFSET+r_id*8+1) ];
        r_out.ser_FOOD2        = this.golden_DRAM[ (DRAM_OFFSET+r_id*8+2) ];
        r_out.ser_FOOD3        = this.golden_DRAM[ (DRAM_OFFSET+r_id*8+3) ];
        return r_out;
    endfunction

    function set_res(Restaurant_id r_id, res_info r_info);
        this.golden_DRAM[ (DRAM_OFFSET+r_id*8)   ] = r_info.limit_num_orders;
        this.golden_DRAM[ (DRAM_OFFSET+r_id*8+1) ] = r_info.ser_FOOD1;
        this.golden_DRAM[ (DRAM_OFFSET+r_id*8+2) ] = r_info.ser_FOOD2;
        this.golden_DRAM[ (DRAM_OFFSET+r_id*8+3) ] = r_info.ser_FOOD3;
    endfunction

    function D_man_Info get_d_man(Delivery_man_id d_id);
        D_man_Info d_out;
        d_out.ctm_info1 = {this.golden_DRAM[ (DRAM_OFFSET+d_id*8+4) ], this.golden_DRAM[ (DRAM_OFFSET+d_id*8+5) ]};
        d_out.ctm_info2 = {this.golden_DRAM[ (DRAM_OFFSET+d_id*8+6) ], this.golden_DRAM[ (DRAM_OFFSET+d_id*8+7) ]};
        return d_out;
    endfunction

    function set_d_man(Delivery_man_id d_id, D_man_Info d_info);
        {this.golden_DRAM[ (DRAM_OFFSET+d_id*8+4) ], this.golden_DRAM[ (DRAM_OFFSET+d_id*8+5) ]} = d_info.ctm_info1;
        {this.golden_DRAM[ (DRAM_OFFSET+d_id*8+6) ], this.golden_DRAM[ (DRAM_OFFSET+d_id*8+7) ]} = d_info.ctm_info2;
    endfunction
endclass

class dataCheckMgr;
    logic       gold_complete;
    Error_Msg   gold_err_msg;
    logic[63:0] gold_info;

    logic       your_complete;
    Error_Msg   your_err_msg;
    logic[63:0] your_info;

    function setGold(logic complete_in, Error_Msg err_msg_in, logic[63:0] info_in);
        gold_complete = complete_in;
        gold_err_msg  = err_msg_in;
        gold_info     = info_in;
    endfunction

    function setYour(logic complete_in, Error_Msg err_msg_in, logic[63:0] info_in);
        your_complete = complete_in;
        your_err_msg  = err_msg_in;
        your_info     = info_in;
    endfunction

    function bit compare();
        // Wrong return false
        // Correct return true
        if ( your_complete !== gold_complete || your_info !== gold_info || your_err_msg !== gold_err_msg ) begin
            void'(this.display());
            return 0;
        end
        else return 1;
    endfunction

    function display();
        $display("\033[1;41m==============================\033[0m");
        $display("\033[1;41m=        Output Info         =\033[0m");
        $display("\033[1;41m==============================\033[0m");
        $display("----------------------------------------------------------------");
        $display("       [Complete] | [   Err Msg   ] | [      Info      ]");
        $display("[Gold] [%8d] | [%13s] | [%16h]", this.gold_complete, this.gold_err_msg.name(), this.gold_info);
        $display("[Your] [%8d] | [%13s] | [%16h]", this.your_complete, this.your_err_msg.name(), this.your_info);
        $display("----------------------------------------------------------------\n");
    endfunction
endclass

class uberMgr;
    Action          cur_action;
    // Restaurant
    Restaurant_id   uberResId;
    res_info        oldResInfo;  // original
    res_info        newResInfo;  // after action
    // Delivery Man
    Delivery_man_id uberDManId;
    D_man_Info      oldDManInfo; // original
    D_man_Info      newDManInfo; // after action
    // Dram
    dramData        u_Dram;
    // Data check manager
    dataCheckMgr    m_data_check;
    logic           gold_complete;
    Error_Msg       gold_err_msg;
    logic[63:0]     gold_info;

    function new();
        u_Dram = new();
        m_data_check = new();
        void'(this.reset());
    endfunction

    function reset();
        cur_action = No_action;

        uberResId = 0;
        oldResInfo = 0;
        newResInfo = 0;

        uberDManId = 0;
        oldDManInfo = 0;
        newDManInfo = 0;

        gold_complete = 0;
        gold_err_msg = No_Err;
        gold_info = 0;
    endfunction

    //----------------
    // Modifier
    //----------------
    function setAction(Action act_in);
        cur_action = act_in;
    endfunction

    function setYour(logic complete_in, Error_Msg err_msg_in, logic[63:0] info_in);
        void'(m_data_check.setYour(complete_in, err_msg_in, info_in));
    endfunction

    //----------------
    // Access Dram
    //----------------
    function getDManFromDram(Delivery_man_id dId_in);
        // Get the current delivery man
        uberDManId  = dId_in;
        oldDManInfo = u_Dram.get_d_man(dId_in);
        newDManInfo = oldDManInfo;
    endfunction

    function getResFromDram(Restaurant_id rId_in);
        // Get the customer's restaurant
        uberResId  = rId_in;
        oldResInfo = u_Dram.get_res(rId_in);
        newResInfo = oldResInfo;
    endfunction

    //----------------
    // Check
    //----------------
    function bit check();
        if(m_data_check.compare() === 0) begin
            if(cur_action == Take) begin
                void'(displayRes());
                void'(displayDMan());
            end
            else if(cur_action == Deliver) begin
                void'(displayDMan());
            end
            else if(cur_action == Order) begin
                void'(displayRes());
            end
            else if(cur_action == Cancel) begin
                void'(displayRes());
                void'(displayDMan());
            end
            return 0;
        end
        return 1;
    endfunction

    //----------------
    // Take
    //----------------
    function take(Delivery_man_id dId_in, Ctm_Info ctmInfo_in);
        void'(this.getDManFromDram(dId_in));
        void'(this.getResFromDram(ctmInfo_in.res_ID));

        // Delivery man busy
        if(newDManInfo.ctm_info2.ctm_status !== None) begin
            gold_complete = 0;
            gold_err_msg  = D_man_busy;
            gold_info     = 0;
        end
        // No enough food
        else if(ctmInfo_in.food_ID == FOOD1 && newResInfo.ser_FOOD1 < ctmInfo_in.ser_food) begin
            gold_complete = 0;
            gold_err_msg  = No_Food;
            gold_info     = 0;
        end
        else if(ctmInfo_in.food_ID == FOOD2 && newResInfo.ser_FOOD2 < ctmInfo_in.ser_food) begin
            gold_complete = 0;
            gold_err_msg  = No_Food;
            gold_info     = 0;
        end
        else if(ctmInfo_in.food_ID == FOOD3 && newResInfo.ser_FOOD3 < ctmInfo_in.ser_food) begin
            gold_complete = 0;
            gold_err_msg  = No_Food;
            gold_info     = 0;
        end
        // Correct
        else begin
            // Complete, No error
            gold_complete = 1;
            gold_err_msg = No_Err;
            // Update Res
            if     (ctmInfo_in.food_ID == FOOD1) newResInfo.ser_FOOD1 -= ctmInfo_in.ser_food;
            else if(ctmInfo_in.food_ID == FOOD2) newResInfo.ser_FOOD2 -= ctmInfo_in.ser_food;
            else if(ctmInfo_in.food_ID == FOOD3) newResInfo.ser_FOOD3 -= ctmInfo_in.ser_food;
            // Update DMan
            if (newDManInfo.ctm_info1.ctm_status == None || (newDManInfo.ctm_info1.ctm_status == Normal && ctmInfo_in.ctm_status == VIP)) begin
                Ctm_Info ctm_info_tmp = newDManInfo.ctm_info1;
                newDManInfo.ctm_info1 = ctmInfo_in;
                newDManInfo.ctm_info2 = ctm_info_tmp;
            end
            else begin
                newDManInfo.ctm_info2 = ctmInfo_in;
            end
            // Set Dram
            void'(u_Dram.set_d_man(uberDManId, newDManInfo));
            void'(u_Dram.set_res(uberResId, newResInfo));
            gold_info = {newDManInfo, newResInfo};
        end

        void'(m_data_check.setGold(gold_complete, gold_err_msg, gold_info));
        // void'(m_data_check.display());
        // void'(displayRes());
        // void'(displayDMan());
    endfunction

    //----------------
    // Deliver
    //----------------
    function deliver(Delivery_man_id dId_in);
        void'(this.getDManFromDram(dId_in));

        // No customers
        if(newDManInfo.ctm_info1.ctm_status === None && newDManInfo.ctm_info2.ctm_status === None) begin
            gold_complete = 0;
            gold_err_msg  = No_customers;
            gold_info     = 0;
        end
        // Correct, deliver customer1
        else begin
            // Complete, No error
            gold_complete = 1;
            gold_err_msg = No_Err;
            // Update DMan
            newDManInfo.ctm_info1 = newDManInfo.ctm_info2;
            newDManInfo.ctm_info2 = {None, 8'd0, No_food, 4'd0};
            // Set Dram
            void'(u_Dram.set_d_man(uberDManId, newDManInfo));
            gold_info = {newDManInfo, 32'd0};
        end

        void'(m_data_check.setGold(gold_complete, gold_err_msg, gold_info));
        // void'(m_data_check.display());
        // void'(displayDMan());
    endfunction

    //----------------
    // Order
    //----------------
    function order(Restaurant_id rId_id, food_ID_servings foodInfo_in);
        void'(this.getResFromDram(rId_id));
        // Restaurant busy
        if(newResInfo.limit_num_orders < newResInfo.ser_FOOD1+newResInfo.ser_FOOD2+newResInfo.ser_FOOD3+foodInfo_in.d_ser_food) begin
            gold_complete = 0;
            gold_err_msg  = Res_busy;
            gold_info     = 0;
        end
        // Correct
        else begin
            // Complete, No error
            gold_complete = 1;
            gold_err_msg = No_Err;
            // Update Res
            if     (foodInfo_in.d_food_ID == FOOD1) newResInfo.ser_FOOD1 += foodInfo_in.d_ser_food;
            else if(foodInfo_in.d_food_ID == FOOD2) newResInfo.ser_FOOD2 += foodInfo_in.d_ser_food;
            else if(foodInfo_in.d_food_ID == FOOD3) newResInfo.ser_FOOD3 += foodInfo_in.d_ser_food;
            // Set Dram
            void'(u_Dram.set_res(uberResId, newResInfo));
            gold_info = {32'd0, newResInfo};
        end

        void'(m_data_check.setGold(gold_complete, gold_err_msg, gold_info));
        // void'(m_data_check.display());
        // void'(displayRes());
    endfunction

    //----------------
    // Cancel
    //----------------
    function cancel(Restaurant_id rId_id, Food_id fId_in, Delivery_man_id dId_in);
        void'(this.getDManFromDram(dId_in));
        void'(this.getResFromDram(rId_id));

        // Wrong cancel
        if(newDManInfo.ctm_info1.ctm_status === None && newDManInfo.ctm_info2.ctm_status === None) begin
            gold_complete = 0;
            gold_err_msg  = Wrong_cancel;
            gold_info     = 0;
        end
        // Wrong restaurant Id
        else if(newDManInfo.ctm_info1.res_ID !== rId_id && newDManInfo.ctm_info2.res_ID !== rId_id) begin
            gold_complete = 0;
            gold_err_msg  = Wrong_res_ID;
            gold_info     = 0;
        end
        // Wrong food Id
        else if(newDManInfo.ctm_info1.food_ID !== fId_in && newDManInfo.ctm_info2.food_ID !== fId_in) begin
            gold_complete = 0;
            gold_err_msg  = Wrong_food_ID;
            gold_info     = 0;
        end
        // Correct
        else begin
            // Complete, No error
            gold_complete = 1;
            gold_err_msg = No_Err;
            
            // For customer 1
            if(newDManInfo.ctm_info1.res_ID === rId_id && newDManInfo.ctm_info1.food_ID === fId_in) begin
                newDManInfo.ctm_info1 = {None, 8'd0, No_Food, 4'd0};
            end
            // For customer 2
            if(newDManInfo.ctm_info2.res_ID === rId_id && newDManInfo.ctm_info2.food_ID === fId_in) begin
                newDManInfo.ctm_info2 = {None, 8'd0, No_Food, 4'd0};
            end
            // Update DMan
            if(newDManInfo.ctm_info1.ctm_status === None) begin
                newDManInfo.ctm_info1 = newDManInfo.ctm_info2;
            end

            // Set Dram
            void'(u_Dram.set_d_man(uberDManId, newDManInfo));
            gold_info = {newDManInfo, 32'd0};
        end

        void'(m_data_check.setGold(gold_complete, gold_err_msg, gold_info));
        // void'(m_data_check.display());
        // void'(displayRes());
        // void'(displayDMan());
    endfunction

    // Display function
    function displayRes();
        $display("\033[1;42m==============================\033[0m");
        $display("\033[1;42m=     Restaurant Info        =\033[0m");
        $display("\033[1;42m==============================\033[0m");
        $display("----------------------------------------------------------------");
        $display("[Restaurant Id] : %5h", uberResId);
        $display("[    Dram Addr] : %5h", uberResId*8 + DRAM_OFFSET);
        $display("----------------------------------------------------------------");
        $display("      [Limit Order] | [Serv Food1] | [Serv Food2] | [Serv Food3]");
        $display("[Old] [%11d] | [%10d] | [%10d] | [%10d]", this.oldResInfo.limit_num_orders, this.oldResInfo.ser_FOOD1, this.oldResInfo.ser_FOOD2, this.oldResInfo.ser_FOOD3);
        $display("[New] [%11d] | [%10d] | [%10d] | [%10d]", this.newResInfo.limit_num_orders, this.newResInfo.ser_FOOD1, this.newResInfo.ser_FOOD2, this.newResInfo.ser_FOOD3);
        $display("----------------------------------------------------------------\n");
    endfunction

    function displayDMan();
        $display("\033[1;43m================================\033[0m");
        $display("\033[1;43m=     Delivery Man Info        =\033[0m");
        $display("\033[1;43m================================\033[0m");
        $display("----------------------------------------------------------------");
        $display("[Delivery Man Id] : %5h", uberDManId);
        $display("[      Dram Addr] : %5h", uberDManId*8 + 4 + DRAM_OFFSET);
        $display("----------------------------------------------------------------");
        $display("           [Ctm Status] | [Res Id] | [Food Type] | [Serv Food]");
        $display("[Old Ctm1] [%10s] | [0x%4h] | [%9s] | [%9d]", this.oldDManInfo.ctm_info1.ctm_status.name(), this.oldDManInfo.ctm_info1.res_ID, this.oldDManInfo.ctm_info1.food_ID.name(), this.oldDManInfo.ctm_info1.ser_food);
        $display("[Old Ctm2] [%10s] | [0x%4h] | [%9s] | [%9d]", this.oldDManInfo.ctm_info2.ctm_status.name(), this.oldDManInfo.ctm_info2.res_ID, this.oldDManInfo.ctm_info2.food_ID.name(), this.oldDManInfo.ctm_info2.ser_food);
        $display("[New Ctm1] [%10s] | [0x%4h] | [%9s] | [%9d]", this.newDManInfo.ctm_info1.ctm_status.name(), this.newDManInfo.ctm_info1.res_ID, this.newDManInfo.ctm_info1.food_ID.name(), this.newDManInfo.ctm_info1.ser_food);
        $display("[New Ctm2] [%10s] | [0x%4h] | [%9s] | [%9d]", this.newDManInfo.ctm_info2.ctm_status.name(), this.newDManInfo.ctm_info2.res_ID, this.newDManInfo.ctm_info2.food_ID.name(), this.newDManInfo.ctm_info2.ser_food);
        $display("----------------------------------------------------------------\n");
    endfunction
endclass
