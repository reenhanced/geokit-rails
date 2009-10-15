module Geokit
  module Adapters
    class Abstract
      class NotImplementedError < StandardError ; end
      
      cattr_accessor :loaded
      
      class << self
        def load(klass) ; end
      end
      
      def initialize(klass)
        @owner = klass
      end
      
      def method_missing(method, *args, &block)
        return @owner.send(method, *args, &block) if @owner.respond_to?(method)
        super
      end

      def distance_sql(origin, units, formula)
        case formula
        when :sphere
          sql = sphere_distance_sql(origin, units)
        when :flat
          sql = flat_distance_sql(origin, units)
        when :simple
          sql = simple_flat_distance_sql(origin, units)
        end
        sql
      end

      # Returns the distance SQL using the spherical world formula (Haversine).  The SQL is tuned
      # to the database in use.
      def sphere_distance_sql(origin, units)
        lat,lng,multiplier = decode_sphere_distance(origin,units)

        #   raise NotImplementedError, '#sphere_distance_sql is not implemented'
        clat=Math.cos(lat)
        clng=Math.cos(lng)
        slat=Math.sin(lat)
        slng=Math.sin(lng)

        #would be nice to store these as columns in the database
        rlat="RADIANS(#{qualified_lat_column_name})"
        rlng="RADIANS(#{qualified_lng_column_name})"
        %|
          (ACOS(#{least_function_name}(1,#{clat}*#{clng}*COS(#{rlat})*COS(#{rlng})+
          #{clat}*#{slng}*COS(#{rlat})*SIN(#{rlng})+
          #{slat}*SIN(#{rlat})))*#{multiplier})
         |
      end
      # %|
      #     (ACOS(least(1,COS(#{lat})*COS(#{lng})*COS(RADIANS(#{qualified_lat_column_name}))*COS(RADIANS(#{qualified_lng_column_name}))+
      #     COS(#{lat})*SIN(#{lng})*COS(RADIANS(#{qualified_lat_column_name}))*SIN(RADIANS(#{qualified_lng_column_name}))+
      #     SIN(#{lat})*SIN(RADIANS(#{qualified_lat_column_name}))))*#{multiplier})
      # |
      # 
      #     (ACOS(min(1,cos(h$11)*cos(j$11)*COS(h12)*COS(j12)+
      #     cos(h$11)*sin(j$11)*COS(h12)*SIN(j12)+
      #     SIN(h$11)*SIN(h12)))*n$11
      # 
      #     =(ACOS(MIN(1,COS(H$11)*COS(J$11)*COS(H12)*COS(J12)+COS(H$11)*SIN(J$11)*COS(H12)*SIN(J12)+SIN(H$11)*SIN(H12)))*N$11)

      # Returns the distance SQL using the flat-world formula (Phythagorean Theory).  The SQL is tuned
      # to the database in use.
      def flat_distance_sql(origin, units)
        lat_degree_units,lng_degree_units = decode_flat_distance(origin, units)
        lat_dist="#{lat_degree_units}*(#{origin.lat}-#{qualified_lat_column_name})"
        lng_dist="#{lng_degree_units}*(#{origin.lng}-#{qualified_lng_column_name})"

        #wonder if A*A or POW(A,2) is quicker - pull out lat_degree_units*lat_degree_units to reduce load
        sql="SQRT(POW(#{lat_dist},2)+POW(#{lng_dist},2))"
      end

      # Returns the distance SQL using the flat-world formula (Phythagorean Theory).
      # Further simplified to not use SQRT - (Even less accurate)
      def simple_flat_distance_sql(origin, units)
        lat_degree_units,lng_degree_units = decode_flat_distance(origin, units)
        lat_dist="#{lat_degree_units}*(#{origin.lat}-#{qualified_lat_column_name})"
        lng_dist="#{lng_degree_units}*(#{origin.lng}-#{qualified_lng_column_name})"

        min_factor=0.415
        max_factor=0.945
        #since we are not using POW, we need to use ABS to make positive
        lat_dist="ABS(#{lat_dist})"
        lng_dist="ABS(#{lng_dist})"
        #sqlite uses max for most and min for least
        sql="(#{least_function_name}(#{lat_dist},#{lng_dist})*#{min_factor}+#{most_function_name}(#{lat_dist},#{lng_dist})*#{max_factor})"
      end
      
      def most_function_name
        'greatest'
      end
      def least_function_name
        'least'
      end
      def decode_sphere_distance(origin, units)
        lat = deg2rad(origin.lat)
        lng = deg2rad(origin.lng)
        multiplier = units_sphere_multiplier(units)
        [lat,lng,multiplier]
      end

      def decode_flat_distance(origin, units)
        lat_degree_units = units_per_latitude_degree(units) #69.1
        lng_degree_units = units_per_longitude_degree(origin.lat, units) #69.1 and cos... aka 53.0
        [lat_degree_units, lng_degree_units]
      end
    end
  end
end