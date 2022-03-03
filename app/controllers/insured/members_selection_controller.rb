class Insured::MembersSelectionController < ApplicationController

    # {"change_plan"=>"change_by_qle", "change_plan_date"=>"03/01/2022", "person_id"=>"60abddc907f0114a15b15227", "qle_id"=>"5b758a3307f0114bc18ecb1d", "sep_id"=>"6220f850d44d053fe620fbc3", "controller"=>"insured/members_selection", "action"=>"new"}
    def new
        binding.pry

        Organizers::MembersSelectionPrevaricationAdapter.call(params: params.symbolize_keys)
    end

    def create
    end
end