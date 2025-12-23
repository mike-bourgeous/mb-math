module MB
  module M
    # Methods on MB::M for working with vectors.
    module VectorMethods
      # Reflects the +vector+ across the (hyper)plane through the origin
      # defined by the given +normal+ vector.
      def reflect(vector, normal)
        case vector
        when Vector
          vdot = vector.dot(normal)
          vdot = vdot.to_r if vdot.is_a?(Integer)
          vector - 2 * vdot / normal.dot(normal) * normal

        when Numo::NArray
          dot = (vector * normal).sum
          normdot = (normal * normal).sum
          vector - 2 * dot / normdot * normal

        when Array
          reflect(Vector[*vector], Vector[*normal]).to_a

        else
          raise "Unsupported type #{vector.class}"
        end
      end
    end
  end
end
