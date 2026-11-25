# frozen_string_literal: true

module SEPA
  # Collection of stateless helpers used by builder stages to emit common
  # XML fragments (addresses, contacts, agent BIC, remittance info, etc.).
  # Most helpers are data-only; `build_agent_bic` is the exception that
  # takes a profile to select the right BIC tag and LEI emission.
  module XmlBuilder
    module_function

    # Element order follows PostalAddress27 XSD sequence (the superset).
    # Fields absent in older schemas are rejected by XSD validation.
    POSTAL_ADDRESS_FIELDS = [
      %i[CareOf care_of],
      %i[Dept department],
      %i[SubDept sub_department],
      %i[StrtNm street_name],
      %i[BldgNb building_number],
      %i[BldgNm building_name],
      %i[Flr floor],
      %i[UnitNb unit_number],
      %i[PstBx post_box],
      %i[Room room],
      %i[PstCd post_code],
      %i[TwnNm town_name],
      %i[TwnLctnNm town_location_name],
      %i[DstrctNm district_name],
      %i[CtrySubDvsn country_sub_division],
      %i[Ctry country_code],
      %i[AdrLine address_line1],
      %i[AdrLine address_line2]
    ].freeze

    # Element order follows Contact13 XSD sequence (the superset).
    # Othr (OtherContact1) and PrefrdMtd are handled separately.
    CONTACT_DETAILS_FIELDS = [
      %i[NmPrfx name_prefix],
      %i[Nm name],
      %i[PhneNb phone_number],
      %i[MobNb mobile_number],
      %i[FaxNb fax_number],
      %i[URLAdr url_address],
      %i[EmailAdr email_address],
      %i[EmailPurp email_purpose],
      %i[JobTitl job_title],
      %i[Rspnsblty responsibility],
      %i[Dept department]
    ].freeze

    def build_postal_address(builder, address)
      return unless address

      builder.PstlAdr do
        POSTAL_ADDRESS_FIELDS.each do |xml_tag, attr|
          value = address.public_send(attr)
          builder.__send__(xml_tag, value) if value
        end
      end
    end

    def build_agent_bic(builder, bic, profile, fallback: true, lei: nil)
      lei_emitted = lei && profile.supports?(:lei)

      builder.FinInstnId do
        # XSD sequence: BICFI/BIC → ClrSysMmbId → LEI → Nm → PstlAdr → Othr
        builder.__send__(profile.features.bic_tag, bic) if bic
        builder.LEI(lei) if lei_emitted
        if !bic && !lei_emitted && fallback
          builder.Othr do
            builder.Id('NOTPROVIDED')
          end
        end
      end
    end

    def build_remittance_information(builder, transaction)
      has_structured = transaction.structured_remittance_information || transaction.additional_remittance_information
      return unless transaction.remittance_information || has_structured

      builder.RmtInf do
        if has_structured
          builder.Strd do
            build_creditor_reference_information(builder, transaction) if transaction.structured_remittance_information
            Array(transaction.additional_remittance_information).each { |info| builder.AddtlRmtInf(info) }
          end
        else
          builder.Ustrd(transaction.remittance_information)
        end
      end
    end

    def build_creditor_reference_information(builder, transaction)
      builder.CdtrRefInf do
        ref_type = transaction.structured_remittance_reference_type || 'SCOR'
        builder.Tp do
          builder.CdOrPrtry { builder.Cd(ref_type) }
          builder.Issr(transaction.structured_remittance_issuer) if transaction.structured_remittance_issuer
        end
        builder.Ref(transaction.structured_remittance_information)
      end
    end

    # Writes `<InitgPty>`. Profiles with `single_initiating_party_element`
    # (PSA) get exactly one child: the id when the account sets an explicit
    # initiating party identification, otherwise the name.
    def build_initiating_party(builder, account, profile)
      builder.InitgPty do
        if !profile.features.single_initiating_party_element
          builder.Nm(account.name)
          account.initiating_party_id(builder, profile)
          build_contact_details(builder, account.contact_details)
        elsif account.explicit_initiating_party_id?
          account.initiating_party_id(builder, profile)
        else
          builder.Nm(account.name)
        end
      end
    end

    def build_contact_details(builder, contact_details)
      return unless contact_details

      builder.CtctDtls do
        CONTACT_DETAILS_FIELDS.each do |xml_tag, attr|
          value = contact_details.public_send(attr)
          builder.__send__(xml_tag, value) if value
        end
        contact_details.other_contacts&.each do |contact|
          builder.Othr do
            builder.ChanlTp(contact[:channel_type])
            builder.Id(contact[:id]) if contact[:id]
          end
        end
        builder.PrefrdMtd(contact_details.preferred_method) if contact_details.preferred_method
      end
    end

    def build_purpose(builder, purpose_code)
      return unless purpose_code

      builder.Purp { builder.Cd(purpose_code) }
    end

    def build_iban_account(builder, tag, iban)
      builder.__send__(tag) do
        builder.Id do
          builder.IBAN(iban)
        end
      end
    end

    def format_amount(value)
      format('%.2f', value)
    end
  end
end
