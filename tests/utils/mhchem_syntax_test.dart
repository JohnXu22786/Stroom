// Tests for the mhchem (\ce / \pu) support preprocessor.
//
// Background: the app renders math with flutter_math_fork (a Dart port of
// KaTeX). KaTeX itself does NOT load the mhchem extension by default, so
// `\ce{...}` is an undefined control sequence and every chemical formula
// falls back to the raw red error text. [preprocessMhchem] rewrites the
// mhchem syntax into plain KaTeX (upright elements, sub/superscripts,
// arrows, states, bonds, ...) that flutter_math_fork can render.
//
// Expected outputs follow the official mhchemParser (mhchem/mhchemParser,
// used by KaTeX's mhchem contrib), simplified to what the Dart port
// supports (no \hphantom/\llap/\vphantom alignment gymnastics, which render
// identically here).

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:stroom/utils/mhchem_syntax.dart';

void main() {
  group(r'preprocessMhchem - \ce basic formulas', () {
    test('H2O becomes an upright formula with a subscript', () {
      // Regression: \ce{H2O} used to be passed to KaTeX verbatim and throw
      // "Undefined control sequence: \ce" (raw red text in the chat).
      expect(preprocessMhchem(r'\ce{H2O}'), r'{\mathrm{H_2O}}');
    });

    test('CO2 - multi-letter elements and one subscript', () {
      expect(preprocessMhchem(r'\ce{CO2}'), r'{\mathrm{CO_2}}');
    });

    test('CH3COOH - subscript applies to the preceding letter run', () {
      expect(preprocessMhchem(r'\ce{CH3COOH}'), r'{\mathrm{CH_3COOH}}');
    });

    test('C12H22O11 - multi-digit subscripts are braced', () {
      expect(preprocessMhchem(r'\ce{C12H22O11}'),
          r'{\mathrm{C_{12}H_{22}O_{11}}}');
    });

    test('NaCl - a plain letter run stays one upright group', () {
      expect(preprocessMhchem(r'\ce{NaCl}'), r'{\mathrm{NaCl}}');
    });

    test('pH and iPr - upright entities are formulas, not coefficients', () {
      // Regression: `p` used to be parsed as a variable coefficient, giving
      // `p\,\mathrm{H}` ("p H"). mhchem treats pH/pOH/pK/pC/iPr/iBu as
      // upright entities.
      expect(preprocessMhchem(r'\ce{pH}'), r'{\mathrm{pH}}');
      expect(preprocessMhchem(r'\ce{iPr}'), r'{\mathrm{iPr}}');
    });
  });

  group('preprocessMhchem - charges and scripts', () {
    test('SO4^2- - explicit caret charge becomes a superscript', () {
      expect(preprocessMhchem(r'\ce{SO4^2-}'), r'{\mathrm{SO_4}^{2-}}');
    });

    test('Na+ - implicit charge attached to the formula', () {
      expect(preprocessMhchem(r'\ce{Na+}'), r'{\mathrm{Na}^{+}}');
    });

    test('Cl- - implicit negative charge at phrase end', () {
      expect(preprocessMhchem(r'\ce{Cl-}'), r'{\mathrm{Cl}^{-}}');
    });

    test('Fe^3+ and Y^{99+} - braced and unbraced charge numbers', () {
      expect(preprocessMhchem(r'\ce{Fe^3+}'), r'{\mathrm{Fe}^{3+}}');
      expect(preprocessMhchem(r'\ce{Y^{99+}}'), r'{\mathrm{Y}^{99+}}');
    });

    test('[AgCl2]- - charge after a bracket group', () {
      expect(preprocessMhchem(r'\ce{[AgCl2]-}'), r'{\mathrm{[AgCl_2]}^{-}}');
    });

    test('e- - electron renders as e with a superscript charge', () {
      expect(preprocessMhchem(r'\ce{e-}'), r'{\mathrm{e}^{-}}');
    });

    test('2e- + 2H+ -> H2 - electrons with coefficients', () {
      expect(
          preprocessMhchem(r'\ce{2e- + 2H+ -> H2}'),
          r'{2\,\mathrm{e}^{-} {}+{} 2\,\mathrm{H}^{+} '
          r'{}\mathrel{\longrightarrow}{} \mathrm{H_2}}');
    });

    test('NO_x - a single-letter subscript stays italic (variable)', () {
      // mhchem typesets variables in subscripts italic; digits are upright.
      expect(preprocessMhchem(r'\ce{NO_x}'), r'{\mathrm{NO}_{x}}');
    });

    test('Fe(CN)_{6}^{3-} - braced sub/superscripts attach to the group', () {
      expect(preprocessMhchem(r'\ce{Fe(CN)_{6}^{3-}}'),
          r'{\mathrm{Fe(CN)}^{3-}_{6}}');
    });

    test('CO3^2-_{(aq)} - subscripted state of aggregation', () {
      expect(preprocessMhchem(r'\ce{CO3^2-_{(aq)}}'),
          r'{\mathrm{CO_3}^{2-}_{(aq)}}');
    });
  });

  group('preprocessMhchem - groups', () {
    test('Ca(OH)2 - number after a paren group is its subscript', () {
      expect(preprocessMhchem(r'\ce{Ca(OH)2}'), r'{\mathrm{Ca(OH)_2}}');
    });

    test('(NH4)2SO4 - leading group', () {
      expect(preprocessMhchem(r'\ce{(NH4)2SO4}'), r'{\mathrm{(NH_4)_2SO_4}}');
    });

    test('Na(NH4)HPO4 - adjacent groups in one formula', () {
      expect(
          preprocessMhchem(r'\ce{Na(NH4)HPO4}'), r'{\mathrm{Na(NH_4)HPO_4}}');
    });
  });

  group('preprocessMhchem - states of aggregation', () {
    test('HCl(aq) - state renders upright with a small skip', () {
      expect(preprocessMhchem(r'\ce{HCl(aq)}'),
          r'{\mathrm{HCl}\mskip2mu \mathrm{(aq)}}');
    });

    test('H2O(l) + H2O(g) - multiple states in one equation', () {
      expect(
          preprocessMhchem(r'\ce{H2O(l) + H2O(g)}'),
          r'{\mathrm{H_2O}\mskip2mu \mathrm{(l)} {}+{} '
          r'\mathrm{H_2O}\mskip2mu \mathrm{(g)}}');
    });

    test('Na+(aq) - state right after a charge', () {
      expect(preprocessMhchem(r'\ce{Na+(aq)}'),
          r'{\mathrm{Na}^{+}\mskip2mu \mathrm{(aq)}}');
    });

    test('Ca(OH)2 - uppercase inner letters are NOT a state', () {
      // The state pattern is `[a-z]{1,3}`; `(OH)` must stay a group.
      expect(preprocessMhchem(r'\ce{Ca(OH)2}'), r'{\mathrm{Ca(OH)_2}}');
    });
  });

  group('preprocessMhchem - arrows and operators', () {
    test('2H2 + O2 -> 2H2O - coefficients, plus, reaction arrow', () {
      expect(
          preprocessMhchem(r'\ce{2H2 + O2 -> 2H2O}'),
          r'{2\,\mathrm{H_2} {}+{} \mathrm{O_2} '
          r'{}\mathrel{\longrightarrow}{} 2\,\mathrm{H_2O}}');
    });

    test('H2O <=> H+ + OH- - equilibrium arrow', () {
      expect(
          preprocessMhchem(r'\ce{H2O <=> H+ + OH-}'),
          r'{\mathrm{H_2O} {}\mathrel{\rightleftharpoons}{} '
          r'\mathrm{H}^{+} {}+{} \mathrm{OH}^{-}}');
    });

    test('A <- B and A <-> B - left and double arrows', () {
      expect(preprocessMhchem(r'\ce{A <- B}'),
          r'{\mathrm{A} {}\mathrel{\longleftarrow}{} \mathrm{B}}');
      expect(preprocessMhchem(r'\ce{A <-> B}'),
          r'{\mathrm{A} {}\mathrel{\longleftrightarrow}{} \mathrm{B}}');
    });

    test('A <--> B - long double-headed arrow', () {
      expect(preprocessMhchem(r'\ce{A <--> B}'),
          r'{\mathrm{A} {}\mathrel{\longleftrightarrow}{} \mathrm{B}}');
    });

    test('A ->[H2O] B - arrow label uses the same formula syntax', () {
      expect(preprocessMhchem(r'\ce{A ->[H2O] B}'),
          r'{\mathrm{A} {}\mathrel{\xrightarrow{\mathrm{H_2O}}}{} \mathrm{B}}');
    });

    test('A ->[above][below] B - above and below labels', () {
      expect(
          preprocessMhchem(r'\ce{A ->[above][below] B}'),
          r'{\mathrm{A} {}\mathrel{\xrightarrow[\mathrm{below}]'
          r'{\mathrm{above}}}{} \mathrm{B}}');
    });

    test(r'A ->[\Delta] B - TeX commands inside labels pass through', () {
      expect(preprocessMhchem(r'\ce{A ->[\Delta] B}'),
          r'{\mathrm{A} {}\mathrel{\xrightarrow{\mathrm{\Delta}}}{} \mathrm{B}}');
    });

    test('N2 + 3H2 ->[high T] 2NH3 - label with words', () {
      expect(
          preprocessMhchem(r'\ce{N2 + 3H2 ->[high T] 2NH3}'),
          r'{\mathrm{N_2} {}+{} 3\,\mathrm{H_2} '
          r'{}\mathrel{\xrightarrow{\mathrm{high}~\mathrm{T}}}{} '
          r'2\,\mathrm{NH_3}}');
    });
  });

  group('preprocessMhchem - amounts and spacing', () {
    test('2 H2O and 2H2O - space after an amount is ignored', () {
      expect(preprocessMhchem(r'\ce{2 H2O}'), r'{2\,\mathrm{H_2O}}');
      expect(preprocessMhchem(r'\ce{2H2O}'), r'{2\,\mathrm{H_2O}}');
    });

    test('0.5 H2O and 1/2 H2O - decimal and fraction coefficients', () {
      expect(preprocessMhchem(r'\ce{0.5 H2O}'), r'{0.5\,\mathrm{H_2O}}');
      expect(
          preprocessMhchem(r'\ce{1/2 H2O}'), r'{\frac{1}{2}\,\mathrm{H_2O}}');
    });

    test('x Na(NH4)HPO4 - a single letter variable is a coefficient', () {
      expect(preprocessMhchem(r'\ce{x Na(NH4)HPO4}'),
          r'{x\,\mathrm{Na(NH_4)HPO_4}}');
    });

    test('H2O H2O - space between formulas is a thin gap', () {
      expect(
          preprocessMhchem(r'\ce{H2O H2O}'), r'{\mathrm{H_2O}~\mathrm{H_2O}}');
    });
  });

  group('preprocessMhchem - bonds and compounds', () {
    test('C6H5-CHO - single bond between groups', () {
      expect(preprocessMhchem(r'\ce{C6H5-CHO}'),
          r'{\mathrm{C_6H_5}{-}\mathrm{CHO}}');
    });

    test('A-B=C#D - single, double and triple bonds', () {
      expect(preprocessMhchem(r'\ce{A-B=C#D}'),
          r'{\mathrm{A}{-}\mathrm{B}{=}\mathrm{C}{\equiv}\mathrm{D}}');
    });

    test('X-2 - a digit right after a bond is literal, not a subscript', () {
      expect(preprocessMhchem(r'\ce{X-2}'), r'{\mathrm{X}{-}\mathrm{2}}');
    });

    test('CuSO4.5H2O - dot compound with a centered dot', () {
      expect(preprocessMhchem(r'\ce{CuSO4.5H2O}'),
          r'{\mathrm{CuSO_4}\,{\cdot}\,5\,\mathrm{H_2O}}');
    });

    test('CuSO4·5H2O and CuSO4\\cdot5H2O - dot compound spellings', () {
      // Regression: the unicode middle dot used to fall through to raw
      // text, turning the hydrate coefficient into a stray subscript
      // (`\mathrm{CuSO_4}·\mathrm{_5H_2O}`).
      expect(preprocessMhchem(r'\ce{CuSO4·5H2O}'),
          r'{\mathrm{CuSO_4}\,{\cdot}\,5\,\mathrm{H_2O}}');
      expect(preprocessMhchem(r'\ce{CuSO4\cdot5H2O}'),
          r'{\mathrm{CuSO_4}\,{\cdot}\,5\,\mathrm{H_2O}}');
    });

    test('KCr(SO4)2*12H2O - star compound', () {
      expect(preprocessMhchem(r'\ce{KCr(SO4)2*12H2O}'),
          r'{\mathrm{KCr(SO_4)_2}\,{\cdot}\,12\,\mathrm{H_2O}}');
    });
  });

  group('preprocessMhchem - isotopes and arrows for precipitation', () {
    test('^{227}_{90}Th+ - isotope with braced mass/atomic numbers', () {
      expect(preprocessMhchem(r'\ce{^{227}_{90}Th+}'),
          r'{{}^{227}_{90}\mathrm{Th}^{+}}');
    });

    test('^227_90Th+ - isotope without braces', () {
      expect(preprocessMhchem(r'\ce{^227_90Th+}'),
          r'{{}^{227}_{90}\mathrm{Th}^{+}}');
    });

    test('^{0}_{-1}n^{-} - neutron notation', () {
      expect(preprocessMhchem(r'\ce{^{0}_{-1}n^{-}}'),
          r'{{}^{0}_{-1}\mathrm{n}^{-}}');
    });

    test('AgCl v - precipitate down arrow', () {
      expect(preprocessMhchem(r'\ce{AgCl v}'), r'{\mathrm{AgCl}\downarrow}');
    });

    test('CO2 ^ - gas evolution up arrow', () {
      expect(preprocessMhchem(r'\ce{CO2 ^}'), r'{\mathrm{CO_2}\uparrow}');
    });

    test('AgCl v + NaNO3 - precipitate arrow mid-equation', () {
      expect(preprocessMhchem(r'\ce{AgCl v + NaNO3}'),
          r'{\mathrm{AgCl}\downarrow {}+{} \mathrm{NaNO_3}}');
    });
  });

  group('preprocessMhchem - text, math escapes and nesting', () {
    test('{Gluconic Acid} - braced upright text', () {
      expect(preprocessMhchem(r'\ce{{Gluconic Acid} + H2O2}'),
          r'{\text{Gluconic Acid} {}+{} \mathrm{H_2O_2}}');
    });

    test('NaOH(aq,\$\\infty\$) - math escape inside a group', () {
      expect(preprocessMhchem(r'\ce{NaOH(aq,$\infty$)}'),
          r'{\mathrm{NaOH(aq,}\infty\mathrm{)}}');
    });

    test('ZnS(\$c\$) - italic letter inside a paren group', () {
      expect(preprocessMhchem(r'\ce{ZnS($c$)}'), r'{\mathrm{ZnS(}c\mathrm{)}}');
    });

    test('nested \\ce inside a math escape is converted too', () {
      expect(
          preprocessMhchem(r'\ce{CH4 + $\left( \ce{O2 + 2 H2} \right)$}'),
          r'{\mathrm{CH_4} {}+{} \left( '
          r'{\mathrm{O_2} {}+{} 2\,\mathrm{H_2}} \right)}');
    });

    test(r'\color{red}{H2O} - two-arg color command', () {
      expect(preprocessMhchem(r'\ce{\color{red}{H2O}}'),
          r'{{\color{red}{\mathrm{H_2O}}}}');
    });

    test(r'\color{red}H2O - single-arg color switch', () {
      // Regression: without content, \color used to land inside the formula
      // and produce invalid TeX (whole expression fell back to error text).
      expect(preprocessMhchem(r'\ce{\color{red}H2O}'),
          r'{\color{red}\mathrm{H_2O}}');
    });

    test(r'\color{red}H2O\color{blue}CO2 - repeated color switches', () {
      // Regression: a later brace group used to be misread as the color
      // content, corrupting the formula into unparseable TeX.
      expect(preprocessMhchem(r'\ce{\color{red}H2O\color{blue}CO2}'),
          r'{\color{red}\mathrm{H_2O}\color{blue}\mathrm{CO_2}}');
    });
  });

  group('preprocessMhchem - \\pu physical units', () {
    test('123 kJ/mol - unit with a slash', () {
      expect(preprocessMhchem(r'\pu{123 kJ/mol}'),
          r'{123\,\mathrm{kJ}\,/\,\mathrm{mol}}');
    });

    test('123 kJ//mol - stacked fraction', () {
      expect(preprocessMhchem(r'\pu{123 kJ//mol}'),
          r'{\frac{123\,\mathrm{kJ}}{\mathrm{mol}}}');
    });

    test('123 kJ*mol-1 - dot and negative exponent', () {
      expect(preprocessMhchem(r'\pu{123 kJ*mol-1}'),
          r'{123\,\mathrm{kJ}\,{\cdot}\,\mathrm{mol}^{-1}}');
    });

    test('1.2e3 J and 2x10^5 m - scientific notation', () {
      expect(
          preprocessMhchem(r'\pu{1.2e3 J}'), r'{1.2\cdot 10^{3}\,\mathrm{J}}');
      expect(
          preprocessMhchem(r'\pu{2x10^5 m}'), r'{2\times 10^{5}\,\mathrm{m}}');
    });

    test('1.0e-3 M, 2E5 m and 2 x 10^5 m - exponent variants', () {
      expect(preprocessMhchem(r'\pu{1.0e-3 M}'),
          r'{1.0\cdot 10^{-3}\,\mathrm{M}}');
      expect(preprocessMhchem(r'\pu{2E5 m}'), r'{2\cdot 10^{5}\,\mathrm{m}}');
      expect(preprocessMhchem(r'\pu{2 x 10^5 m}'),
          r'{2\times 10^{5}\,\mathrm{m}}');
    });

    test('mol L-1 - exponent on a bare unit', () {
      expect(preprocessMhchem(r'\pu{mol L-1}'),
          r'{\mathrm{mol}\,\mathrm{L}^{-1}}');
    });

    test('m s^-2 and 5 m^2 - exponents on units', () {
      expect(
          preprocessMhchem(r'\pu{m s^-2}'), r'{\mathrm{m}\,\mathrm{s}^{-2}}');
      expect(preprocessMhchem(r'\pu{5 m^2}'), r'{5\,\mathrm{m}^{2}}');
    });

    test('25 °C - temperature unit', () {
      expect(preprocessMhchem(r'\pu{25 °C}'), '{25\\,{}^{\\circ}C}');
    });

    test('3 J = 1.2 kJ - operator passes through', () {
      expect(preprocessMhchem(r'\pu{3 J = 1.2 kJ}'),
          '{3\\,\\mathrm{J}\\,=\\,1.2\\,\\mathrm{kJ}}');
    });
  });

  group('preprocessMhchem - passthrough and safety', () {
    test('plain math is untouched', () {
      const input = r'x^2 + \frac{a}{b} + \int_0^1 dx';
      expect(preprocessMhchem(input), input);
    });

    test('dollar amounts in text are untouched', () {
      const input = r'Cost: $5 and \$10';
      expect(preprocessMhchem(input), input);
    });

    test('\\ce without braces is untouched', () {
      const input = r'\ce H2O';
      expect(preprocessMhchem(input), input);
    });

    test('unbalanced \\ce{ is passed through untouched', () {
      const input = r'\ce{H2O';
      expect(preprocessMhchem(input), input);
    });

    test('empty \\ce becomes an empty group', () {
      expect(preprocessMhchem(r'\ce{}'), r'{}');
    });

    test('multiple \\ce in one expression are all converted', () {
      expect(preprocessMhchem(r'\ce{H2O} and \ce{CO2}'),
          r'{\mathrm{H_2O}} and {\mathrm{CO_2}}');
    });

    test('\\ce mixed with \\pu in one expression', () {
      expect(preprocessMhchem(r'\ce{H2O} + \pu{3 J}'),
          r'{\mathrm{H_2O}} + {3\,\mathrm{J}}');
    });

    test('\\ce inside surrounding math is converted in place', () {
      expect(preprocessMhchem(r'pH = -\log \ce{[H+]}'),
          r'pH = -\log {\mathrm{[H]}^{+}}');
    });

    test('% is escaped so it cannot swallow the closing brace', () {
      // Regression: `%` is a TeX comment character; a raw `%` in the output
      // used to comment out the rest of the expression (red error text).
      expect(preprocessMhchem(r'\ce{50 %}'), r'{50\,\mathrm{\%}}');
      expect(preprocessMhchem(r'\pu{50 %}'), '{50\\,\\%}');
    });
  });

  group('flutter_math_fork integration - the actual bug', () {
    test('raw \\ce fails to parse today (undefined control sequence)', () {
      // Guards that the pipeline test below is meaningful: without the
      // preprocessor, flutter_math_fork cannot render any mhchem input.
      final widget = Math.tex(r'\ce{H2O}');
      expect(widget.parseError, isNotNull);
    });

    test('preprocessed chemical equations parse without errors', () {
      final equations = <String>[
        r'\ce{H2O}',
        r'\ce{2H2 + O2 -> 2H2O}',
        r'\ce{H+ + OH- <=> H2O}',
        r'\ce{H2O <=>[heat] H+ + OH-}',
        r'\ce{Ca(OH)2}',
        r'\ce{SO4^2-}',
        r'\ce{CH3COOH <=> CH3COO- + H+}',
        r'\ce{N2 + 3H2 ->[high T] 2NH3}',
        r'\ce{A ->[above][below] B}',
        r'\ce{A <- B}',
        r'\ce{A <-> B}',
        r'\ce{^{227}_{90}Th+}',
        r'\ce{CuSO4.5H2O}',
        r'\ce{AgCl v}',
        r'\ce{HCl(aq)}',
        r'\ce{2e- + 2H+ -> H2}',
        r'\ce{NaOH(aq,$\infty$)}',
        r'\ce{pH}',
        r'\ce{{Gluconic Acid}}',
        r'\ce{\color{red}H2O}',
        r'\pu{123 kJ/mol}',
        r'\pu{25 °C}',
        r'\pu{1.0e-3 M}',
      ];
      for (final eq in equations) {
        final widget = Math.tex(preprocessMhchem(eq));
        expect(widget.parseError, isNull, reason: 'failed to render: $eq');
      }
    });
  });
}
