import '../model/models.dart';

/// Common medicine names for suggestions while typing: international
/// generic names with brand names sold in Israel, in English and Hebrew.
/// Each line is one medicine; any of its names can be typed. Only names,
/// written for this app (no doses, no medical data, no third-party list);
/// the user can always type something else.
const builtInMedicines = <List<String>>[
  ['Paracetamol', 'Acamol', 'אקמול', 'Dexamol', 'דקסמול', 'Tylenol', 'פרצטמול'],
  ['Ibuprofen', 'Nurofen', 'נורופן', 'Advil', 'אדויל', 'איבופרופן'],
  ['Dipyrone', 'Metamizole', 'Optalgin', 'אופטלגין'],
  ['Aspirin', 'אספירין', 'Micropirin', 'מיקרופירין', 'Cartia', 'קרטיה'],
  ['Diclofenac', 'Voltaren', 'וולטרן', 'דיקלופנק'],
  ['Naproxen', 'Naxyn', 'נקסין', 'נפרוקסן'],
  ['Tramadol', 'Tramadex', 'טרמדקס', 'טרמדול'],
  ['Amoxicillin', 'Moxypen', 'מוקסיפן', 'אמוקסיצילין'],
  ['Amoxicillin and clavulanic acid', 'Augmentin', 'אוגמנטין'],
  ['Azithromycin', 'Azenil', 'אזניל', 'Zithromax', 'אזיתרומיצין'],
  ['Cefuroxime', 'Zinnat', 'זינאט'],
  ['Cefalexin', 'Ceforal', 'צפורל'],
  ['Ciprofloxacin', 'Ciproxin', 'ציפרוקסין'],
  ['Nitrofurantoin', 'Macrodantin', 'מקרודנטין'],
  ['Trimethoprim and sulfamethoxazole', 'Resprim', 'רספרים'],
  ['Fluconazole', 'Diflucan', 'דיפלוקן'],
  ['Acyclovir', 'Zovirax', 'זוביראקס'],
  ['Oseltamivir', 'Tamiflu', 'טמיפלו'],
  ['Nystatin', 'Mycostatin', 'מיקוסטטין'],
  ['Mupirocin', 'Bactroban', 'בקטרובן'],
  ['Hydrocortisone', 'הידרוקורטיזון'],
  ['Prednisolone', 'פרדניזולון'],
  ['Prednisone', 'פרדניזון'],
  ['Dexamethasone', 'דקסמתזון'],
  ['Salbutamol', 'Ventolin', 'ונטולין'],
  ['Budesonide', 'Pulmicort', 'פולמיקורט'],
  ['Fluticasone', 'Flixotide', 'פליקסוטייד'],
  ['Montelukast', 'Singulair', 'סינגולייר'],
  ['Cetirizine', 'Zyrtec', 'זירטק'],
  ['Loratadine', 'Claritin', 'לורטדין'],
  ['Desloratadine', 'Aerius', 'איריוס'],
  ['Fexofenadine', 'Telfast', 'טלפסט'],
  ['Saline nose drops', 'טיפות מלח לאף'],
  ['Omeprazole', 'Omepradex', 'אומפרדקס', 'Losec'],
  ['Esomeprazole', 'Nexium', 'נקסיום'],
  ['Pantoprazole', 'Controloc', 'קונטרולוק'],
  ['Lansoprazole', 'לנסופרזול'],
  ['Famotidine', 'פמוטידין'],
  ['Domperidone', 'Motilium', 'מוטיליום'],
  ['Ondansetron', 'Zofran', 'זופרן'],
  ['Loperamide', 'Imodium', 'אימודיום'],
  ['Lactulose', 'לקטולוז'],
  ['Macrogol', 'Movicol', 'מוביקול'],
  ['Probiotics', 'פרוביוטיקה'],
  ['Simvastatin', 'Simovil', 'סימוביל'],
  ['Atorvastatin', 'Lipitor', 'ליפיטור'],
  ['Rosuvastatin', 'Crestor', 'קרסטור'],
  ['Metformin', 'Glucophage', 'גלוקופאג', 'Glucomin', 'גלוקומין'],
  ['Empagliflozin', 'Jardiance', "ג'רדיאנס"],
  ['Sitagliptin', 'Januvia', "ג'נוביה"],
  ['Insulin', 'אינסולין'],
  ['Amlodipine', 'Norvasc', 'נורבסק'],
  ['Ramipril', 'Tritace', 'טריטייס'],
  ['Enalapril', 'אנלפריל'],
  ['Losartan', 'Ocsaar', 'אוקסאר'],
  ['Bisoprolol', 'Cardiloc', 'קרדילוק'],
  ['Metoprolol', 'Lopresor', 'לופרסור'],
  ['Furosemide', 'Fusid', 'פוסיד'],
  ['Hydrochlorothiazide', 'הידרוכלורותיאזיד'],
  ['Clopidogrel', 'Plavix', 'פלביקס'],
  ['Apixaban', 'Eliquis', 'אליקוויס'],
  ['Rivaroxaban', 'Xarelto', 'קסרלטו'],
  ['Warfarin', 'Coumadin', 'קומדין'],
  ['Levothyroxine', 'Eltroxin', 'אלטרוקסין', 'Euthyrox', 'יותירוקס'],
  ['Allopurinol', 'Zyloric', 'זילוריק'],
  ['Colchicine', 'קולכיצין'],
  ['Alendronate', 'Fosalan', 'פוסלן'],
  ['Tamsulosin', 'Omnic', 'אומניק'],
  ['Finasteride', 'Proscar', 'פרוסקר'],
  ['Donepezil', 'Aricept', 'אריספט'],
  ['Memantine', 'Ebixa', 'אביקסה'],
  ['Levodopa and carbidopa', 'Sinemet', 'סינמט'],
  ['Sertraline', 'Lustral', 'לוסטרל'],
  ['Escitalopram', 'Cipralex', 'ציפרלקס'],
  ['Citalopram', 'Recital', 'ריסיטל'],
  ['Fluoxetine', 'Prozac', 'פרוזק'],
  ['Mirtazapine', 'Remeron', 'רמרון'],
  ['Quetiapine', 'Seroquel', 'סרוקוול'],
  ['Zolpidem', 'Stilnox', 'סטילנוקס'],
  ['Clonazepam', 'Clonex', 'קלונקס'],
  ['Lorazepam', 'Lorivan', 'לוריבן'],
  ['Methylphenidate', 'Ritalin', 'ריטלין', 'Concerta', 'קונצרטה'],
  ['Levetiracetam', 'Keppra', 'קפרה'],
  ['Valproic acid', 'Depalept', 'דפלפט'],
  ['Lamotrigine', 'Lamictal', 'למיקטל'],
  ['Betahistine', 'Betaserc', 'בטאסרק'],
  ['Vitamin D', 'ויטמין D', 'ויטמין די'],
  ['Vitamin B12', 'ויטמין B12'],
  ['Iron', 'ברזל'],
  ['Folic acid', 'חומצה פולית'],
  ['Calcium', 'סידן'],
  ['Magnesium', 'מגנזיום'],
  ['Omega 3', 'אומגה 3'],
];

/// One suggestion: [name] to fill in, the medicine's other names to show
/// under it, and the family's own medicine when it's one of theirs.
class MedicineSuggestion {
  const MedicineSuggestion(this.name, {this.also = const [], this.saved});
  final String name;
  final List<String> also;
  final Medication? saved;
}

abstract final class MedicineNames {
  static const max = 8;

  static String _norm(String s) => s.trim().toLowerCase();

  /// Whether a word of [name] starts with [q] ("clav" finds "Amoxicillin
  /// and clavulanic acid").
  static bool matches(String name, String q) {
    final n = _norm(name);
    if (n.startsWith(q)) return true;
    for (final sep in const [' ', '-', '(', '/']) {
      if (n.contains('$sep$q')) return true;
    }
    return false;
  }

  /// The family's own medicines first, then the built-in names, at most
  /// [max]. Nothing until two letters are typed, and nothing once the
  /// field already holds exactly one name.
  static List<MedicineSuggestion> suggest(
    String query,
    Iterable<Medication> family,
  ) {
    final q = _norm(query);
    if (q.length < 2) return const [];
    final out = <MedicineSuggestion>[];
    final seen = <String>{};
    for (final m in family) {
      if (out.length >= max) break;
      if (!matches(m.name, q) || !seen.add('${_norm(m.name)}|${m.sameKey}')) {
        continue;
      }
      out.add(MedicineSuggestion(m.name, saved: m));
    }
    final familyNames = {for (final m in family) _norm(m.name)};
    for (final names in builtInMedicines) {
      if (out.length >= max) break;
      for (final n in names) {
        if (!matches(n, q)) continue;
        final key = _norm(n);
        if (familyNames.contains(key) || !seen.add(key)) break;
        out.add(
          MedicineSuggestion(
            n,
            also: [
              for (final o in names)
                if (o != n) o,
            ],
          ),
        );
        break;
      }
    }
    if (out.length == 1 && _norm(out.single.name) == q) return const [];
    return out;
  }
}
