module MB
  module M
    class Plot
      # Represents a function (i.e. y=x^2) for GNUplot.
      class Function
        class DependentVariable
          def initialize(name, function)
            @name = name
            @function = function
            @closed = false
          end

          def to_s
            @name
          end

          def close
            @closed = true
          end

          def method_missing(name, *args, **kwargs)
            puts 'depvar closed' if @closed # XXX
            super if @closed
            super if name == :to_hash # Ruby 2.7.x
            puts "\e[34mdep var #{@name} received #{name} #{args} #{kwargs}\n\t#{MB::U.highlight(caller_locations[0..4]).lines.join("\t")}\e[0m" # XXX
            @function.memoizer.method_missing(name, *args, **kwargs, receiver: self)
          end
        end

        class IndependentVariable
          def initialize(name, function)
            @name = name
            @function = function
            @closed = false
          end

          def to_s
            @name
          end

          def close
            @closed = true
          end

          def method_missing(name, *args, **kwargs)
            puts 'indvar closed' if @closed # XXX
            super if @closed
            super if name == :to_hash # Ruby 2.7.x
            puts "\e[35mindep var #{@name} received #{name} #{args} #{kwargs}\n\t#{MB::U.highlight(caller_locations[0..4]).lines.join("\t")}\e[0m" # XXX
            @function.memoizer.method_missing(name, *args, **kwargs, receiver: self)
          end
        end

        class Expression
          def initialize(name, args, function)
            @name = name
            @args = args
            @function = function
            @closed = false
          end

          def to_s
            if @args.length == 1 && @name.to_s.end_with?('@')
              "(#{@name[0..-2]}#{@args[0]})"
            else
              "(#{@args.map(&:to_s).join(" #{@name} ")})"
            end
          end

          def close
            @closed = true
          end

          # TODO: dedupe; these are all expressions maybe
          def method_missing(name, *args, **kwargs)
            puts 'expr closed' if @closed # XXX
            super if @closed
            super if name == :to_hash # Ruby 2.7.x
            puts "\e[38;5;177mexpression var #{@name} received #{name} #{args} #{kwargs}\n\t#{MB::U.highlight(caller_locations[0..4]).lines.join("\t")}\e[0m" # XXX
            @function.memoizer.method_missing(name, *args, **kwargs, receiver: self)
          end
        end

        class Memoizer
          def initialize(function)
            @function = function
          end

          def method_missing(name, *args, receiver: @function, **kwargs)
            dbginf = "#{receiver.class.name}.#{name} #{args} #{kwargs}\n\t#{MB::U.highlight(caller_locations[0..4]).lines.join("\t")}"
            name = name.to_s
            ret = @function

            case name
            when /\A[a-z][a-z0-9_]*\z/
              if args.empty?
                puts "\e[33mindependent variable: #{dbginf}\e[0m" # XXX
                @function.indvars[name] ||= IndependentVariable.new(name, @function)
                ret = @function.indvars[name]
              else
                puts "\e[36mfunction call: #{dbginf}\e[0m" # XXX
                # TODO: dedupe; these are all expressions maybe
                # TODO: built-in functions like sin/cos/exp?
                if @function.depvars[name]
                  puts "found dependent variable #{@function.depvars[name]} for function call" # XXX
                else
                  puts "no ind var #{name} found!" # XXX
                end
              end

            when /\A[a-z][a-z0-9_]*=\z/
              puts "\e[32mdependent variable: #{dbginf}\e[0m" # XXX
              # TODO: argument should be an expression
              # TODO: might want to use @y= instead of self.y=
              @function.depvars[name[0..-2]] = {var: DependentVariable.new(name[0..-2], @function), args: args, kwargs: kwargs}
              ret = @function.depvars[name[0..-2]][:var]

            when /\A([*+-\/^]|\*\*)@?\z/
              puts "\e[31moperator: #{dbginf}\e[0m" # XXX
              raise "Can't operate on the memoizer!  This is a confusing error message!" if receiver == self
              ret = Expression.new(name, [receiver, *args], @function)

            else
              puts "\e[38;5;110munknown call: #{dbginf}\e[0m" # XXX
            end

            # FIXME: this basically needs to build a syntax tree kind of like Hashformer HF::G.chain
            @function.calls << {object: ret, receiver: receiver, name: name, args: args, kwargs: kwargs}

            ret
          end
        end

        # XXX
        attr_reader :indvars, :depvars, :calls, :memoizer

        # TODO
        def initialize(&block)
          @indvars = {}
          @depvars = {}
          @calls = []
          @memoizer = Memoizer.new(self)
          @final = @memoizer.instance_exec(&block)
          @final.close if @final.respond_to?(:close)
          puts "final: #{@final}" # XXX
        end

        def to_s
          @final.to_s
        end
      end
    end
  end
end
