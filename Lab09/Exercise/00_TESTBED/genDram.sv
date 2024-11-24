`include "../00_TESTBED/Usertype_FD.sv"

module GEN_DRAM ();

//===================================
// PARAMETERS & VARIABLES
//===================================
parameter DRAM_OFFSET = 'h10000;
parameter USER_NUM    = 256;
integer   SEED        = 5200122;

integer addr;
integer file;

//===================================
// Restaurant & Customer Info
//===================================
// Restaurant Info
limit_of_orders  limit_num_orders;
servings_of_FOOD ser_FOOD1;
servings_of_FOOD ser_FOOD2;
servings_of_FOOD ser_FOOD3;

// Delivery man Info
Customer_status  ctm_status_1; // 2
Restaurant_id    res_ID_1; // 8
Food_id          food_ID_1; // 2
servings_of_food ser_food_1; // 4

Customer_status  ctm_status_2;
Restaurant_id    res_ID_2;
Food_id          food_ID_2;
servings_of_food ser_food_2;

//================================================================
//      CLASS RANDOM
//================================================================
// Random Restaurant
class random_order_num_mgr;
    rand limit_of_orders ran_order_num;
    function new ( int seed );
        this.srandom(seed);
    endfunction
endclass
random_order_num_mgr rOrderNum = new(SEED);

class random_food_num_mgr;
    rand servings_of_FOOD ran_food_num;
    servings_of_FOOD rangeMax;
    function new ( int seed );
        this.srandom(seed);
        rangeMax = 0;
    endfunction
    // Sum of food should be less than order num
    constraint range{
        ran_food_num inside { [0:rangeMax] };
    }
endclass
random_food_num_mgr rFoodNum = new(SEED);

// Random Customer
class random_ctm_sts_mgr;
    rand Customer_status ran_ctm_sts;
    function new ( int seed );
        this.srandom(seed);
    endfunction
    constraint range{
        ran_ctm_sts inside { None, Normal, VIP };
    }
endclass
random_ctm_sts_mgr rCtmSts = new(SEED);

class random_res_id_mgr;
    rand Restaurant_id ran_res_id;
    function new ( int seed );
        this.srandom(seed);
    endfunction
endclass
random_res_id_mgr rResId = new(SEED);

class random_food_id_mgr;
    rand Food_id ran_food_id_type;
    function new ( int seed );
        this.srandom(seed);
    endfunction
    constraint range{
        ran_food_id_type inside { FOOD1, FOOD2, FOOD3 };
    }
endclass
random_food_id_mgr rFoodId = new(SEED);

class random_serv_food_mgr;
    rand servings_of_food ran_serv_food_num;
    function new ( int seed );
        this.srandom(seed);
    endfunction
endclass
random_serv_food_mgr rServFood = new(SEED);

initial begin
    file = $fopen("../00_TESTBED/DRAM/dram.dat","w");
    for( addr=DRAM_OFFSET ; addr<((DRAM_OFFSET+USER_NUM*8)-1) ; addr=addr+'h8 )  begin
        //**************
        // Restaurant
        //**************
        void'(rOrderNum.randomize());
        limit_num_orders = rOrderNum.ran_order_num;
        
        // Specific range
        rFoodNum.rangeMax = limit_num_orders/3;

        void'(rFoodNum.randomize());
        ser_FOOD1 = rFoodNum.ran_food_num;
        void'(rFoodNum.randomize());
        ser_FOOD2 = rFoodNum.ran_food_num;
        void'(rFoodNum.randomize());
        ser_FOOD3 = rFoodNum.ran_food_num;

        $display("%h",addr);
        $display("%h %h %h %h",limit_num_orders, ser_FOOD1, ser_FOOD2, ser_FOOD3);

        $fwrite(file, "@%5h\n", addr);
        $fwrite(file, "%h %h %h %h\n", limit_num_orders, ser_FOOD1, ser_FOOD2, ser_FOOD3);

        //**************
        // Delivery
        //**************
        void'(rCtmSts.randomize());
        ctm_status_1 = rCtmSts.ran_ctm_sts;
        if(ctm_status_1 == None) begin
            // Ctm1 == None
            // Ctm2 should be also None
            res_ID_1 = 0;
            food_ID_1 = No_food;
            ser_food_1 = 0;

            ctm_status_2 = None;
            res_ID_2 = 0;
            food_ID_2 = No_food;
            ser_food_2 = 0;
        end
        else begin
            // Ctm1 != None
            void'(rResId.randomize());
            res_ID_1 = rResId.ran_res_id;
            void'(rFoodId.randomize());
            food_ID_1 = rFoodId.ran_food_id_type;
            void'(rServFood.randomize());
            ser_food_1 = rServFood.ran_serv_food_num;

            void'(rCtmSts.randomize());
            ctm_status_2 = rCtmSts.ran_ctm_sts;
            if(ctm_status_2 == None) begin
                res_ID_2 = 0;
                food_ID_2 = No_food;
                ser_food_2 = 0;
            end
            else begin
                void'(rResId.randomize());
                res_ID_2 = rResId.ran_res_id;
                void'(rFoodId.randomize());
                food_ID_2 = rFoodId.ran_food_id_type;
                void'(rServFood.randomize());
                ser_food_2 = rServFood.ran_serv_food_num;
            end
        end
        
        

        $display("%h",addr+'h4);
        $display("%h %h %h %h",ctm_status_1, res_ID_1, food_ID_1, ser_food_1);
        $display("%h %h %h %h",ctm_status_2, res_ID_2, food_ID_2, ser_food_2);

        $fwrite(file, "@%5h\n", addr+'h4);
        $fwrite(file, "%h %h %h %h\n", {ctm_status_1, res_ID_1[7:2]}, {res_ID_1[1:0], {food_ID_1, ser_food_1}}, {ctm_status_2, res_ID_2[7:2]}, {res_ID_2[1:0], {food_ID_2, ser_food_2}});

    end
    $fclose(file);
    $display("=================================");
    $display("= Generate DRAM Data Successful =");
    $display("=================================");
end

endmodule
