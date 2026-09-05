module Administration
  module AgenciesHelper
    def agency_country_code_choices(selected = nil)
      include_current_choice(country_code_choices, selected)
    end

    def agency_timezone_choices(selected = nil)
      groups = timezone_identifiers.group_by { |identifier| timezone_group(identifier) }
      grouped = groups.sort_by { |group, _| group }.to_h.transform_values do |identifiers|
        identifiers.sort.map { |identifier| [ identifier, identifier ] }
      end

      if selected.present? && timezone_identifiers.exclude?(selected)
        { "Current" => [ [ selected, selected ] ] }.merge(grouped)
      else
        grouped
      end
    end

    private

    def country_code_choices
      TZInfo::Country.all
        .map { |country| [ "#{country.name} (#{country.code})", country.code ] }
        .sort_by { |label, _code| label }
    end

    def timezone_identifiers
      @timezone_identifiers ||= TZInfo::Timezone.all_identifiers
    end

    def timezone_group(identifier)
      identifier.include?("/") ? identifier.split("/", 2).first : "Other"
    end

    def include_current_choice(choices, selected)
      return choices if selected.blank? || choices.any? { |_, value| value == selected }

      [ [ selected, selected ], *choices ]
    end
  end
end
