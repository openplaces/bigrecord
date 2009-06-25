# This doesn't need to be in the Embedded namespace, but it's placed here for organization.

module Embedded

class WebLink < BigRecord::Embedded

  column :url,           :string
  column :title,         :string

end

end