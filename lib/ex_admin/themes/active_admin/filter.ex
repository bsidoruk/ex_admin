Code.ensure_compiled(ExAdmin.Utils)
defmodule ExAdmin.Theme.ActiveAdmin.Filter do
  @moduledoc false
  require Logger
  require Ecto.Query
  import ExAdmin.Utils
  import ExAdmin.Filter
  use Xain

  def theme_filter_view(conn, defn, q, order, scope) do
    markup do
      div "#filters_sidebar_sectionl.sidebar_section.panel" do
        h3 "Filters"
        div ".panel_contents" do
          form "accept-charset": "UTF-8", action: get_route_path(conn, :index), class: "filter_form", id: "q_search", method: "get" do
            if scope do
              input type: :hidden, name: :scope, value: scope
            end
            for field <- fields(defn), do: build_field(field, q, defn)
            div ".buttons" do
              input name: "commit", type: "submit", value: "Filter"
              a ".clear_filters_btn Clear Filters", href: "#"
              order_value = if order, do: order, else: "id_desc"
              input id: "order", name: "order", type: :hidden, value: order_value
            end
          end
        end
      end
    end

  end

  def build_field({name, :string}, q, _) do
    name_field = "#{name}_contains"
    value = if q, do: Map.get(q, name_field, ""), else: ""
    div ".filter_form_field.filter_string" do
      label ".label Search #{humanize name}", for: "q_#{name}"
      input id: "q_#{name}", name: "q[#{name_field}]", type: :text, value: value
    end
  end

  def build_field({name, type}, q, _) when type in [Ecto.DateTime, Ecto.Date, Ecto.Time] do
    gte_value = get_value("#{name}_gte", q)
    lte_value = get_value("#{name}_lte", q)
    div ".filter_form_field.filter_date_range" do
      label ".label #{humanize name}", for: "q_#{name}_gte"
      input class: "datepicker", id: "q_#{name}_gte", max: "10", name: "q[#{name}_gte]", size: "12", type: :text, value: gte_value
      span ".seperator -"
      input class: "datepicker", id: "q_#{name}_lte", max: "10", name: "q[#{name}_lte]", size: "12", type: :text, value: lte_value
    end
  end

  def build_field({name, num}, q, defn) when num in [:integer, :id, :decimal] do
    unless check_and_build_association(name, q, defn) do
      selected_name = integer_selected_name(name, q)
      value = get_integer_value name, q
      div ".filter_form_field.filter_numeric" do
        label ".label #{humanize name}", for: "#{name}_numeric"
        select onchange: ~s|document.getElementById("#{name}_numeric").name="q[" + this.value + "]";| do
          for {suffix, text} <- integer_options do
            build_option(text, "#{name}_#{suffix}", selected_name)
          end
        end
        input id: "#{name}_numeric", name: "q[#{selected_name}]", size: "10", type: "text", value: value
      end
    end
  end

  def build_field({name, %Ecto.Association.BelongsTo{related: assoc, owner_key: owner_key}}, q, _) do
    id = "q_#{owner_key}"
    if assoc.__schema__(:type, :name) do
      repo = Application.get_env :ex_admin, :repo
      resources = repo.all Ecto.Query.select(assoc, [c], {c.id, c.name})
      selected_key = case q["#{owner_key}_eq"] do
        nil -> nil
        val -> val
      end
      div ".filter_form_field.filter_select" do
        title = humanize(name) |> String.replace(" Id", "")
        label ".label #{title}", for: "q_#{owner_key}"
        select "##{id}", [name: "q[#{owner_key}_eq]"] do
          option "Any", value: ""
          for {id, name} <- resources do
            selected = if "#{id}" == selected_key, do: [selected: :selected], else: []
            option name, [{:value, "#{id}"} | selected]
          end
        end
      end
    end
  end

  def build_field({name, :boolean}, q, _) do
    name_field = "#{name}_eq"
    opts = [id: "q_#{name}", name: "q[#{name_field}]", type: :checkbox, value: "true"]
    new_opts = if q do
      if Map.get(q, name_field, nil), do: [{:checked, :checked} | opts], else: opts
    else
      opts
    end
    div ".filter_form_field.filter_boolean" do
      label ".label #{humanize name}", for: "q_#{name}"
      input new_opts
    end
  end

  def build_field({name, Ecto.UUID}, q, defn) do
    repo = Application.get_env :ex_admin, :repo
    ids = repo.all(defn.resource_model)
    |> Enum.map(&(Map.get(&1, name)))

    selected_key = case q["#{name}_eq"] do
      nil -> nil
      val -> val
    end

    div ".filter_form_field.filter_select" do
      title = humanize(name)
      label ".label #{title}", for: "q_#{name}"
      select "##{name}", [name: "q[#{name}_eq]"] do
        option "Any", value: ""
        for id <- ids do
          selected = if "#{id}" == selected_key, do: [selected: :selected], else: []
          option id, [{:value, "#{id}"} | selected]
        end
      end
    end
  end

  def build_field({name, type}, _q, _) do
    Logger.debug "ExAdmin.Filter: unknown type: #{inspect type} for field: #{inspect name}"
    nil
  end


end
