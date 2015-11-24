# == Schema Information
#
# Table name: downgrade_actions
#
#  id                :integer          not null, primary key
#  archive_format_id :integer          not null
#  months            :integer          not null
#  bitrate           :integer
#  channels          :integer
#
class DowngradeAction < ActiveRecord::Base

  belongs_to :archive_format

  validates :months, presence: true, uniqueness: { scope: :archive_format_id }
  validates :months, :bitrate, :channels,
            numericality: { only_integer: true, greater_than: 0, allow_blank: true }

end