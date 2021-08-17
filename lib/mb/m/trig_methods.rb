module MB
  module M
    # Methods related to trigonometry.
    module TrigMethods
      TWO_PI = 2.0 * Math::PI

      # Returns the relative angle between two complex numbers regardless of
      # their magnitude, in the range [-pi, pi).  The returned value is the
      # rotation to apply to +a+ to make its ray coincident with +b+.
      # Returns a positive value if +a+ is clockwise of +b+.
      # Returns a negative value if +a+ is counterclockwise of +b+.
      # Returns 0 if one or both numbers are zero.
      def angle(a, b)
        c = b.arg - a.arg
        c += TWO_PI while c < -Math::PI
        c -= TWO_PI while c >= Math::PI
        c
      end

      # The first antiderivative of the cosecant function, using exponential
      # instead of sine to preserve both real and imaginary components.
      #
      # This is only expected to work correctly for real arguments.
      #
      # The imaginary part of the output looks like a square wave.
      #
      # See https://en.wikipedia.org/wiki/Integral_of_the_secant_function#Hyperbolic_forms
      # See https://www.wolframalpha.com/input/?i=INTEGRATE+%282i%2F%28e%5E%28i*z%29-e%5E%28-i*z%29%29%29
      def csc_int(x)
        # Scale and offset adjusted to match plot on Wolfram Alpha
        # FIXME: this does not return the correct imaginary component when given an imaginary argument
        -2.0 * CMath.atanh(CMath.exp(1i * x)).conj + Math::PI / 2i
      end

      # The second antidervative of the cosecant (or at least the
      # antiderivative of #csc_int).  Only accepts real arguments, only
      # accurate to ~5 decimal places (and possibly less when very close to
      # x=0).
      #
      # The imaginary part of the output looks like a triangle wave.
      #
      # Sage command: f = integrate(-2*atanh(e^(i*x)), x)
      def csc_int_int(x)
        lookup_integrate_2_arctanh_e_i_x_x(x)
      end

      # Direct implementation of the second antiderivative of the cosecant,
      # using the dilogarithm function.
      # This is extremely slow (~100ms+ per call).
      def csc_int_int_direct(x)
        # The derivative (#csc_int) has discontinuities at 0 and pi so we have
        # to fill in these gaps.
        return 2.46740110027234i if x == 0
        return -2.46740110027234i if x == Math::PI || x == -Math::PI

        x * (CMath.log(CMath.exp(1i * x) + 1) - CMath.log(CMath.exp(1i * x) - 1)) -
          2 * x * CMath.atanh(CMath.exp(1i * x)) +
          1i * CMath.log(-CMath.exp(1i * x)) * CMath.log(CMath.exp(1i * x) + 1) +
          x * CMath.log(CMath.exp(1i * x) - 1) +
          1i * dilog(CMath.exp(1i * x) + 1) -
          1i * dilog(-CMath.exp(1i * x) + 1)
      end

      # The first antiderivative of a modified cotangent function, arrived at
      # through a combination of exponential identities and trial and error.
      #
      # The imaginary part of the output looks like a sawtooth wave.
      #
      # Modified exponential cotangent to drop the negative exponent term from the sine.
      # Sage command: integrate(e ^ (i * z) / (i * (e ^ (-i * z) - e ^ (i * z))), z)
      # Sage result: 1/2*log(e^(I*z) + 1) + 1/2*log(e^(I*z) - 1)
      # Modified to produce ramp: 2/pi * log(e^(I*z) + I) + I
      def cot_int(x)
        -2.0 / Math::PI * CMath.log(CMath.exp(1i * x) + 1i) + 1i
      end

      # Returns an approximation of the cycloid as a function of +x+.  A
      # cycloid is the curve produced by a point at the circumference of a
      # wheel moving horizontally without slipping.
      #
      # The cycloid can only be described either parametrically, or as a
      # function of Y, and not as a function of X.  This approximation uses a
      # lookup table and interpolation to get around that limitation.
      def cycloid(x)
        @cyc ||= cycloid_table(tmin: -0.1 * Math::PI, tmax: 2.1 * Math::PI, steps: 881)

        x %= 2.0 * Math::PI
        idx = @cyc.bsearch_index { |v| v[0] >= x }

        v1 = @cyc[idx - 1]
        v2 = @cyc[idx]

        x1 = v1[0]
        x2 = v2[0]
        t = (x - x1) / (x2 - x1)

        MB::M.interp(v1[1], v2[1], t)
      end

      # Generates a table of the cycloid, with t ranging from +:tmin+ to
      # +:tmax+ in the given number of +:steps+.  The resulting X and Y values
      # are scaled by +:xscale+ and +:yscale+.  If +:power+ is not 1, then the
      # shape of each individual cycloid is altered.  Using a power of 1.12
      # gives a pretty good approximation of the curve of #csc_int_int.
      def cycloid_table(tmin: -10 * Math::PI, tmax: 10 * Math::PI, xscale: 1, yscale: 1, steps: 1001, power: 1)
        Numo::DFloat.linspace(tmin, tmax, steps).to_a.map { |t|
          cycloid_parametric(t, xscale: xscale, yscale: yscale, power: power)
        }
      end

      # Returns the value of the cycloid at time +t+, as an [x, y] Array.  See
      # #cycloid_table for other parameter descriptions.
      def cycloid_parametric(t, xscale: 1, yscale: 1, power: 1)
        x = t - Math.sin(t)
        y = 1 - Math.cos(t)
        y = y ** power * 2.0 ** (1 - power) if power != 1

        [x * xscale, y * yscale]
      end

      private

      # Automatically generated lookup table of integrate(-2 * arctanh(e ^ (i * x)), x) from -1.5707963267948966 to 0.0
      # Generated by experiments/lookup_table.rb from mb-math
      # experiments/lookup_table.rb "integrate(-2 * arctanh(e ^ (i * x)), x)" -1.5707963267948966 0.0 101
      LOOKUP_INTEGRATE_2_ARCTANH_E_I_X_X = Numo::DComplex[
        (1.83193118835444+5.55111512312578e-17i),
        (1.83180781576262+0.0246740110027233i),
        (1.83143766754058+0.0493480220054469i),
        (1.83082065231093+0.0740220330081702i),
        (1.82995661765263+0.0986960440108938i),
        (1.82884534991252+0.123370055013617i),
        (1.82748657394065+0.14804406601634i),
        (1.82587995274862+0.172718077019064i),
        (1.82402508708989+0.197392088021787i),
        (1.82192151496077+0.222066099024511i),
        (1.81956871102062+0.246740110027234i),
        (1.81696608592935+0.271414121029957i),
        (1.81411298560028+0.296088132032681i),
        (1.81100869036592+0.320762143035405i),
        (1.80765241405416+0.345436154038127i),
        (1.80404330297178+0.370110165040851i),
        (1.80018043479205+0.394784176043574i),
        (1.79606281734296+0.419458187046298i),
        (1.79168938729175+0.444132198049021i),
        (1.78705900872171+0.468806209051745i),
        (1.78217047159617+0.493480220054468i),
        (1.77702249010453+0.518154231057191i),
        (1.77161370088461+0.542828242059915i),
        (1.76594266111487+0.567502253062638i),
        (1.76000784646978+0.592176264065362i),
        (1.75380764893088+0.616850275068085i),
        (1.74734037444516+0.641524286070808i),
        (1.74060424042216+0.666198297073532i),
        (1.73359737305989+0.690872308076256i),
        (1.72631780448907+0.715546319078979i),
        (1.71876346972417+0.740220330081702i),
        (1.71093220340876+0.764894341084425i),
        (1.70282173634125+0.789568352087149i),
        (1.69442969176628+0.814242363089872i),
        (1.6857535814152+0.838916374092596i),
        (1.67679080127773+0.863590385095319i),
        (1.66753862708531+0.888264396098042i),
        (1.65799420948445+0.912938407100766i),
        (1.64815456887655+0.937612418103489i),
        (1.63801658989825+0.962286429106213i),
        (1.6275770155137+0.986960440108936i),
        (1.61683244068744+1.01163445111166i),
        (1.60577930560301+1.03630846211438i),
        (1.59441388838922+1.06098247311711i),
        (1.58273229731148+1.08565648411983i),
        (1.57073046238141+1.11033049512255i),
        (1.55840412633249+1.13500450612528i),
        (1.54574883490386+1.159678517128i),
        (1.53275992636771+1.18435252813072i),
        (1.51943252022827+1.20902653913345i),
        (1.5057615050118+1.23370055013617i),
        (1.49174152505741+1.25837456113889i),
        (1.47736696620736+1.28304857214162i),
        (1.46263194028281+1.30772258314434i),
        (1.44753026821644+1.33239659414706i),
        (1.43205546169654+1.35707060514979i),
        (1.41620070315761+1.38174461615251i),
        (1.39995882393024+1.40641862715523i),
        (1.38332228033666+1.43109263815796i),
        (1.36628312748775+1.45576664916068i),
        (1.34883299050186+1.4804406601634i),
        (1.33096303282328+1.50511467116613i),
        (1.31266392126902+1.52978868216885i),
        (1.2939257873736+1.55446269317157i),
        (1.27473818453185+1.5791367041743i),
        (1.25509004035606+1.60381071517702i),
        (1.23496960356404+1.62848472617974i),
        (1.21436438459343+1.65315873718247i),
        (1.19326108899162+1.67783274818519i),
        (1.17164554245173+1.70250675918791i),
        (1.14950260614655+1.72718077019064i),
        (1.12681608074222+1.75185478119336i),
        (1.10356859713828+1.77652879219608i),
        (1.07974149156128+1.80120280319881i),
        (1.05531466211154+1.82587681420153i),
        (1.03026640319184+1.85055082520425i),
        (1.0045732133883+1.87522483620698i),
        (0.978209571264714+1.8998988472097i),
        (0.951147672083024+1.92457285821243i),
        (0.923357116553767+1.94924686921515i),
        (0.894804540171926+1.97392088021787i),
        (0.865453168251795+1.9985948912206i),
        (0.835262277060074+2.02326890222332i),
        (0.804186534892375+2.04794291322604i),
        (0.772175187675088+2.07261692422877i),
        (0.739171040340956+2.09729093523149i),
        (0.705109165640325+2.12196494623421i),
        (0.669915242615786+2.14663895723694i),
        (0.633503381583527+2.17131296823966i),
        (0.595773220410311+2.19598697924238i),
        (0.55660595857116+2.22066099024511i),
        (0.515858793504701+2.24533500124783i),
        (0.473356862775726+2.27000901225055i),
        (0.42888111381683+2.29468302325328i),
        (0.382149146272707+2.319357034256i),
        (0.332783047937946+2.34403104525872i),
        (0.280250838337874+2.36870505626145i),
        (0.223747088396741+2.39337906726417i),
        (0.161903864374734+2.41805307826689i),
        (0.0918401856348807+2.44272708926962i),
        (-8.50583000021389e-15+2.46740110027234i)
      ].real

      # Automatically generated lookup table of integrate(-2 * arctanh(e ^ (i * x)), x) from -0.1 to 0.0
      # Generated by experiments/lookup_table.rb from mb-math
      # experiments/lookup_table.rb "integrate(-2 * arctanh(e ^ (i * x)), x)" -0.1 0.0 21
      SMALL_LOOKUP_INTEGRATE_2_ARCTANH_E_I_X_X = Numo::DComplex[
        [(0.399545439850515+2.31032146759285i),
         (0.384443605455943+2.31817544922682i),
         (0.369078095285853+2.3260294308608i),
         (0.353434288916255+2.33388341249477i),
         (0.337495840580432+2.34173739412875i),
         (0.321244354892652+2.34959137576272i),
         (0.304658975812297+2.3574453573967i),
         (0.287715857726498+2.36529933903067i),
         (0.270387473083062+2.37315332066465i),
         (0.252641688069872+2.38100730229862i),
         (0.234440500179617+2.3888612839326i),
         (0.215738267210309+2.39671526556657i),
         (0.196479142339785+2.40456924720054i),
         (0.176593212908555+2.41242322883452i),
         (0.155990402312772+2.42027721046849i),
         (0.134550231829575+2.42813119210247i),
         (0.112103181494428+2.43598517373644i),
         (0.0883926901258597+2.44383915537042i),
         (0.0629831458876054+2.45169313700439i),
         (0.0349573192633147+2.45954711863837i),
         (0+2.46740110027234i)]
      ].real

      # Handles expansion of quarter-wave lookup table
      def get_lookup_i2aeixx(table, idx)
        # Imaginary component will be generated directly, as quarter-wave lookup does not return the correct values
        l = table.length - 1
        v = MB::M.fetch_bounce(table, idx)
        v *= -1 if idx >= table.length || idx <= -table.length
        v
      end

      # Automatically generated (then manually modified) lookup-table-based
      # approximation of integrate(-2 * arctanh(e ^ (i * x)), x)
      # Uses 101 steps between -1.5707963267948966 and 0.0
      # Generated by experiments/lookup_table.rb from mb-math with the help of Sage
      def lookup_integrate_2_arctanh_e_i_x_x(x, alpha = 0)
        x = (x + Math::PI) % (2.0 * Math::PI) - Math::PI

        if x > -0.09 && x < 0.09
          offset = (x + 0.1) * 20 / 0.1
          table = SMALL_LOOKUP_INTEGRATE_2_ARCTANH_E_I_X_X
        elsif x > Math::PI - 0.098
          offset = (x - Math::PI + 0.1) * -20 / 0.1 + 40
          table = SMALL_LOOKUP_INTEGRATE_2_ARCTANH_E_I_X_X
        elsif x < -Math::PI + 0.098
          offset = (x + Math::PI - 0.1) * -20 / 0.1
          table = SMALL_LOOKUP_INTEGRATE_2_ARCTANH_E_I_X_X
        else
          offset = (x + 1.5707963267948966) * 100 / 1.5707963267948966
          table = LOOKUP_INTEGRATE_2_ARCTANH_E_I_X_X
        end

        idx = offset.floor
        frac = offset - idx
        real = MB::M.catmull_rom(
          get_lookup_i2aeixx(table, idx - 1),
          get_lookup_i2aeixx(table, idx),
          get_lookup_i2aeixx(table, idx + 1),
          get_lookup_i2aeixx(table, idx + 2),
          frac,
          alpha
        )

        # Triangle wave borrowed from mb-sound
        phi = (x - Math::PI / 2) % (2.0 * Math::PI)
        if phi < 0.5 * Math::PI
          # Initial rise from 0..1 in 0..pi/2
          imag = phi * 2.0 / Math::PI
        elsif phi < 1.5 * Math::PI
          # Fall from 1..-1 in pi/2..3pi/2
          imag = 2.0 - phi * 2.0 / Math::PI
        else
          # Final rise from -1..0 in 3pi/2..2pi
          imag = phi * 2.0 / Math::PI - 4.0
        end

        # 2.4674...*i == -pi*log(2) + I*dilog(2)
        Complex(real, -2.46740110027234 * imag)
      end
    end
  end
end
