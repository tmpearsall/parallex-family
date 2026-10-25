class TreesController < ApplicationController
  def show
    tree = FamilyTree.new
    @layout = tree.layout(params[:root])
    @roots = Person.where(id: @layout.root_ids).index_by(&:id)
    @selected = (params[:root].presence || @layout.root_ids.first).to_i
    @people_count = tree.people_count
  end
end
