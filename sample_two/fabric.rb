class Fabric < ActiveRecord::Base
  belongs_to :fabrics_rack
  belongs_to :customer

  self.per_page = 10

  default_scope { order('created_at DESC') }

  validates :fabric_number, presence: true

  def self.import(customer)
    # Imports fabric data from Published google sheets URL stored in Customer

    # TODO: Make datamap into environment variables or settings.
    data_map = {
      fabric_number: 0,
      status: 3
    }

    url = customer.fabrics_url
    valid_fabric  = []
    sleep 5
    xlsx = Roo::Spreadsheet.open(url, extension: :xlsx)
    sheet = xlsx.sheet(0)
    (2..sheet.last_row).each do |i|
      row = sheet.row(i)
      next unless row[data_map[:fabric_number]]
      fabric_number = row[data_map[:fabric_number]]
      valid_fabric <<  fabric_number
      status = row[data_map[:fabric_number]].present? ? "active" : "retired"
      status = row[data_map[:status]] if row[data_map[:status]].present?
      fabrics_url = url

      # Customer fabrics are equal if they have the same fabric# and Fabric URL.
      fabric = Fabric.find_by_fabric_number(fabric_number)

      inserts = []
      if fabric
        # Update existing fabric, if needed
        fabric.update_attributes(status: status) unless fabric.status == status
      else
        inserts.push "('#{fabric_number}', '#{status}', '#{fabrics_url}', '#{Time.current}', '#{Time.current}')"
      end

      # Mass insert
      #  WARNING: Only relatively say from SQL injection.
      #  SQL injection is possible in the google sheets, but access to them is
      #   limited, thus risk is somewhat low. Currently seeking alternatives.
      next if inserts.empty?
      conn = ActiveRecord::Base.connection
      sql = "INSERT INTO fabrics (fabric_number, status, fabrics_url, created_at, updated_at) VALUES #{inserts.join(', ')}"
      conn.execute sql
    end

    #remove extra fabric
    Fabric.all.each do |x|
      x.update_attributes(status: "retired") unless valid_fabric.include?(x.fabric_number)
    end

  end
end

