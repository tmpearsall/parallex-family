class RelationshipsController < TenantController
  def create
    me = current_family.people.find(params[:person_id])
    other = current_family.people.find_by(id: params.dig(:relationship, :other_id))
    kind = params.dig(:relationship, :as)
    rel = case kind
    when "parent"  then current_family.relationships.new(from_person: other, to_person: me, kind: "parent")
    when "child"   then current_family.relationships.new(from_person: me, to_person: other, kind: "parent")
    when "partner" then current_family.relationships.new(from_person: me, to_person: other, kind: "partner")
    end
    if rel && other && rel.save
      redirect_to me, notice: "Recorded."
    else
      redirect_to me, alert: (rel&.errors&.full_messages&.to_sentence.presence || "Choose a person and a relationship.")
    end
  end

  def destroy
    rel = current_family.relationships.find(params[:id])
    back = rel.from_person
    rel.destroy
    redirect_to back, notice: "Removed."
  end
end
