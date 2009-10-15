module Geokit
  module Adapters
    class SQLite < Abstract
      #may want to install a custom function, see the sqlserver code
      def distance_sql(origin, units, formula)
        simple_flat_distance_sql(origin, units)
      end
    end
  end
end