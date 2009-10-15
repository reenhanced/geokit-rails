module Geokit
  module Adapters
    class SQLServer < Abstract
      
      class << self
        
        def load(klass)
          klass.connection.execute <<-EOS
            if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[geokit_least]') and xtype in (N'FN', N'IF', N'TF'))
            drop function [dbo].[geokit_least]
          EOS

          klass.connection.execute <<-EOS
            CREATE FUNCTION [dbo].geokit_least (@value1 float,@value2 float) RETURNS float AS BEGIN
            return (SELECT CASE WHEN @value1 < @value2 THEN  @value1 ELSE @value2 END) END
          EOS
          self.loaded = true
        end
        
      end
      
      def initialize(*args)
        super(*args)
      end
      
      def least_function_name
        '[dbo].geokit_least'
      end
    end
  end
end