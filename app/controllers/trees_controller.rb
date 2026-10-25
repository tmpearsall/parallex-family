class TreesController < TenantController
  def show
    tree = FamilyTree.new(current_family)
    @layout = tree.layout(params[:root])
    @roots = current_family.people.where(id: @layout.root_ids).index_by(&:id)
    @selected = (params[:root].presence || @layout.root_ids.first).to_i
    @people_count = tree.people_count
  end
end
