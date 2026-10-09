import 'models/menu_category.dart';
import 'models/menu_item.dart';

/// Static menu catalogue (mirrors the original web POS menu).
class MenuRepository {
  const MenuRepository();

  static const String customCategoryName = '➕ صنف خارجي / يدوي';

  List<MenuCategory> get categories => _menuData;

  static const List<MenuCategory> _menuData = [
    MenuCategory(
      name: 'الأطباق والوجبات',
      items: [
        MenuItem(name: 'فرخة كاملة', prices: {'وجبة': 400}),
        MenuItem(
          name: '1/2 فرخة مشوية',
          description: '1/2 فرخة مشوية - أرز - بطاطس - سلطة طحينة - عيش',
          prices: {'وجبة': 200},
        ),
        MenuItem(name: 'ربع فرخة صدر', prices: {'وجبة': 120}),
        MenuItem(name: 'ربع فرخة ورك', prices: {'وجبة': 100}),
        MenuItem(
          name: 'شيش طاووك',
          description: 'قطع فراخ - بطاطس - سلطة ثومية - عيش',
          prices: {'وجبة': 220},
        ),
        MenuItem(
          name: 'تشيكن ستريبس زنجر',
          description: 'قطع ستريبس - بطاطس - سلطة ثومية - أرز أو عيش',
          prices: {'وجبة': 220},
        ),
        MenuItem(
          name: 'تشيكن بانيه',
          description: 'قطع فراخ - بطاطس - سلطة ثومية - عيش',
          prices: {'وجبة': 220},
        ),
        MenuItem(
          name: 'ميكس تشيكن',
          description:
              'شيش طاووك - صدور مشوية - فراخ بانيه - ستريبس - بطاطس - سلطة - طحينة - عيش',
          prices: {'وجبة': 250},
        ),
        MenuItem(
          name: 'صدور فراخ مشوية',
          description: 'صدور فراخ - بطاطس - سلطة ثومية - عيش',
          prices: {'وجبة': 220},
        ),
        MenuItem(
          name: 'كبدة إسكندراني',
          description: 'كبدة - بطاطس - سلطة - طحينة - عيش',
          prices: {'وجبة': 180},
        ),
        MenuItem(
          name: 'كفتة مشوية',
          description: 'لحم كفتة - بطاطس - سلطة طحينة - عيش',
          prices: {'وجبة': 220},
        ),
        MenuItem(
          name: 'سجق مشوي أو خلطة',
          description: 'سجق - بطاطس - سلطة طحينة - عيش',
          prices: {'وجبة': 180},
        ),
      ],
    ),
    MenuCategory(
      name: 'وجبات التوفير',
      items: [
        MenuItem(
          name: 'ميكس السعادة',
          description:
              '2 صوبع كفتة + صدر فرخة مشوي + 1 قطعة زنجر + أرز + بطاطس + صوص',
          prices: {'وجبة': 200},
        ),
        MenuItem(
          name: 'وجبة الصحاب',
          description:
              '2 صوبع كفتة + ورك فرخة مشوي + 1 قطعة زنجر + أرز + بطاطس + صوص',
          prices: {'وجبة': 180},
        ),
        MenuItem(
          name: 'وجبة الحرش',
          description: 'مكرونة صوص أحمر + سجق + بطاطس + صوص',
          prices: {'وجبة': 150},
        ),
      ],
    ),
    MenuCategory(
      name: 'الشاورما عالجريل',
      items: [
        MenuItem(
          name: 'سندوتش شاورما فراخ سوري ساده',
          prices: {'سوري': 100, 'فرنساوي': 120},
        ),
        MenuItem(
          name: 'سندوتش شاورما فراخ سوري بالموتزاريلا + بطاطس',
          prices: {'سوري': 120, 'فرنساوي': 140},
        ),
      ],
    ),
    MenuCategory(
      name: 'بورجر اللحم',
      items: [
        MenuItem(name: 'برجر لحم + بطاطس', prices: {'عادي': 130}),
        MenuItem(name: 'برجر لحم جبنة + بطاطس', prices: {'عادي': 160}),
        MenuItem(name: 'برجر فراخ + بطاطس', prices: {'عادي': 120}),
        MenuItem(name: 'برجر فراخ جبنة + بطاطس', prices: {'عادي': 140}),
      ],
    ),
    MenuCategory(
      name: 'سندوتشات لوكس',
      items: [
        MenuItem(name: 'بطاطس سوري', prices: {'عادي': 40}),
        MenuItem(name: 'كبدة اسكندراني', prices: {'صغير': 30, 'كبير': 70}),
        MenuItem(name: 'سجق بالخلطة', prices: {'صغير': 40, 'كبير': 80}),
        MenuItem(name: 'سجق مشوي', prices: {'صغير': 40, 'كبير': 80}),
        MenuItem(name: 'كفتة مشوية', prices: {'صغير': 50, 'كبير': 100}),
        MenuItem(name: 'سوسيس', prices: {'صغير': 40, 'كبير': 80}),
        MenuItem(name: 'فراخ بانيه', prices: {'صغير': 50, 'كبير': 90}),
        MenuItem(name: 'زنجر', prices: {'صغير': 50, 'كبير': 90}),
        MenuItem(name: 'تشيكن كريسبى', prices: {'صغير': 60, 'كبير': 100}),
        MenuItem(name: 'شيوش طاووك', prices: {'صغير': 50, 'كبير': 90}),
        MenuItem(name: 'صدور فراخ مشوية', prices: {'صغير': 50, 'كبير': 90}),
        MenuItem(name: 'تشيكن تشيز', prices: {'صغير': 60, 'كبير': 100}),
        MenuItem(name: 'تونة', prices: {'عادي': 100}),
        MenuItem(name: 'جمبرى بانيه', prices: {'عادي': 120}),
      ],
    ),
    MenuCategory(
      name: 'البيتزا',
      subcategories: [
        MenuSubcategory(
          name: 'بيتزا الجبنة',
          items: [
            MenuItem(
              name: 'بيتزا مارجريتا',
              prices: {'صغير': 75, 'وسط': 125, 'كبير': 190},
            ),
            MenuItem(
              name: 'بيتزا تشيز',
              prices: {'صغير': 75, 'وسط': 125, 'كبير': 190},
            ),
            MenuItem(
              name: 'بيتزا مشكل جبن',
              prices: {'صغير': 120, 'وسط': 170, 'كبير': 230},
            ),
            MenuItem(
              name: 'بيتزا مشروم',
              prices: {'صغير': 120, 'وسط': 170, 'كبير': 230},
            ),
          ],
        ),
        MenuSubcategory(
          name: 'بيتزا الدجاج',
          items: [
            MenuItem(
              name: 'بيتزا زنجر حار',
              prices: {'صغير': 130, 'وسط': 180, 'كبير': 250},
            ),
            MenuItem(
              name: 'بيتزا فراخ صدور',
              prices: {'صغير': 130, 'وسط': 180, 'كبير': 250},
            ),
            MenuItem(
              name: 'بيتزا فراخ باربيكيو',
              prices: {'صغير': 130, 'وسط': 180, 'كبير': 250},
            ),
            MenuItem(
              name: 'بيتزا تشيكن رانش',
              prices: {'صغير': 130, 'وسط': 180, 'كبير': 250},
            ),
            MenuItem(
              name: 'بيتزا سموك تركي',
              prices: {'صغير': 140, 'وسط': 200, 'كبير': 270},
            ),
            MenuItem(
              name: 'بيتزا ميكس فراخ',
              prices: {'صغير': 135, 'وسط': 200, 'كبير': 250},
            ),
          ],
        ),
        MenuSubcategory(
          name: 'بيتزا اللحوم',
          items: [
            MenuItem(
              name: 'بيتزا بسطرمة',
              prices: {'صغير': 120, 'وسط': 170, 'كبير': 230},
            ),
            MenuItem(
              name: 'بيتزا سجق',
              prices: {'صغير': 110, 'وسط': 160, 'كبير': 220},
            ),
            MenuItem(
              name: 'بيتزا لحم مفروم',
              prices: {'صغير': 110, 'وسط': 160, 'كبير': 220},
            ),
            MenuItem(
              name: 'بيتزا سوسيس',
              prices: {'صغير': 110, 'وسط': 160, 'كبير': 220},
            ),
            MenuItem(
              name: 'بيتزا ميكس لحوم',
              prices: {'صغير': 140, 'وسط': 180, 'كبير': 240},
            ),
            MenuItem(
              name: 'بيتزا سلامي',
              prices: {'صغير': 110, 'وسط': 160, 'كبير': 220},
            ),
            MenuItem(
              name: 'بيتزا سوبر سوبريم',
              prices: {'صغير': 140, 'وسط': 180, 'كبير': 240},
            ),
          ],
        ),
        MenuSubcategory(
          name: 'بيتزا الأسماك',
          items: [
            MenuItem(
              name: 'بيتزا تونة',
              prices: {'صغير': 120, 'وسط': 180, 'كبير': 240},
            ),
            MenuItem(
              name: 'بيتزا جمبرى',
              prices: {'صغير': 130, 'وسط': 200, 'كبير': 270},
            ),
            MenuItem(
              name: 'بيتزا سي فود',
              prices: {'صغير': 150, 'وسط': 220, 'كبير': 290},
            ),
          ],
        ),
      ],
    ),
    MenuCategory(
      name: 'فطائر الحادق',
      items: [
        MenuItem(name: 'فطيرة بسطرمة', prices: {'وسط': 160, 'كبير': 250}),
        MenuItem(
          name: 'فطيرة بسطرمة كيري',
          prices: {'وسط': 200, 'كبير': 280},
        ),
        MenuItem(name: 'فطيرة سجق', prices: {'وسط': 150, 'كبير': 230}),
        MenuItem(name: 'فطيرة سجق كيري', prices: {'وسط': 180, 'كبير': 250}),
        MenuItem(name: 'فطيرة لحم مفروم', prices: {'وسط': 150, 'كبير': 230}),
        MenuItem(name: 'فطيرة سوسيس', prices: {'وسط': 150, 'كبير': 230}),
        MenuItem(
          name: 'فطيرة مشكل لحوم',
          prices: {'وسط': 200, 'كبير': 320},
        ),
        MenuItem(name: 'فطيرة جبنة كيري', prices: {'وسط': 150, 'كبير': 230}),
        MenuItem(name: 'فطيرة جبنة رومي', prices: {'وسط': 140, 'كبير': 210}),
        MenuItem(name: 'فطيرة مشكل جبن', prices: {'وسط': 160, 'كبير': 230}),
        MenuItem(name: 'فطيرة فراخ', prices: {'وسط': 160, 'كبير': 240}),
        MenuItem(name: 'فطيرة سموك تركي', prices: {'وسط': 160, 'كبير': 240}),
        MenuItem(name: 'فطيرة تونة', prices: {'وسط': 160, 'كبير': 230}),
        MenuItem(name: 'فطيرة جمبري', prices: {'وسط': 200, 'كبير': 300}),
        MenuItem(name: 'فطيرة سي فود', prices: {'وسط': 220, 'كبير': 320}),
      ],
    ),
    MenuCategory(
      name: 'فطائر الحلو',
      items: [
        MenuItem(
          name: 'فطيرة بالسكر أو الكاستر',
          prices: {'وسط': 50, 'كبير': 100},
        ),
        MenuItem(
          name: 'فطيرة إسكندرانية',
          prices: {'وسط': 120, 'كبير': 200},
        ),
        MenuItem(name: 'فطيرة بغاشة', prices: {'وسط': 60, 'كبير': 120}),
        MenuItem(name: 'فطيرة موز', prices: {'وسط': 100, 'كبير': 180}),
        MenuItem(name: 'فطيرة شيكولاتة', prices: {'وسط': 120, 'كبير': 200}),
        MenuItem(name: 'فطيرة مكسرات', prices: {'وسط': 150, 'كبير': 300}),
        MenuItem(name: 'فطيرة حلو جحا', prices: {'وسط': 170, 'كبير': 320}),
        MenuItem(name: 'فطيرة مشلتت', prices: {'كبير': 120}),
        MenuItem(name: 'طبق عسل', prices: {'عادي': 30}),
        MenuItem(name: 'طبق قشطة', prices: {'عادي': 50}),
        MenuItem(name: 'طبق جبنة قديمة', prices: {'عادي': 30}),
      ],
    ),
    MenuCategory(
      name: 'الكريب',
      subcategories: [
        MenuSubcategory(
          name: 'كريب الجبن',
          items: [
            MenuItem(name: 'كريب موتزاريلا', prices: {'عادي': 75}),
            MenuItem(name: 'كريب مشكل جبن', prices: {'عادي': 130}),
            MenuItem(name: 'كريب بطاطس', prices: {'عادي': 75}),
          ],
        ),
        MenuSubcategory(
          name: 'كريب اللحوم',
          items: [
            MenuItem(name: 'كريب لحمة مفرومة', prices: {'عادي': 100}),
            MenuItem(name: 'كريب سجق', prices: {'عادي': 100}),
            MenuItem(name: 'كريب بسطرمة', prices: {'عادي': 110}),
            MenuItem(name: 'كريب مشكل لحوم', prices: {'عادي': 130}),
            MenuItem(name: 'كريب سوسيس', prices: {'عادي': 100}),
            MenuItem(name: 'كريب سوبر سوبريم', prices: {'عادي': 130}),
            MenuItem(name: 'كريب برجر لحمة', prices: {'عادي': 100}),
            MenuItem(name: 'كريب كفتة', prices: {'عادي': 100}),
            MenuItem(name: 'كريب كبده اسكندراني', prices: {'عادي': 100}),
          ],
        ),
        MenuSubcategory(
          name: 'كريب الفراخ',
          items: [
            MenuItem(name: 'كريب فراخ بانيه', prices: {'عادي': 100}),
            MenuItem(name: 'كريب شاورما فراخ', prices: {'عادي': 120}),
            MenuItem(name: 'كريب فاهيتا', prices: {'عادي': 120}),
            MenuItem(name: 'كريب ميكس تشكين', prices: {'عادي': 125}),
            MenuItem(name: 'كريب شيش طاووك', prices: {'عادي': 120}),
            MenuItem(name: 'كريب كرسبى', prices: {'عادي': 110}),
            MenuItem(name: 'كريب زنجر حار', prices: {'عادي': 120}),
          ],
        ),
        MenuSubcategory(
          name: 'كريب الأسماك',
          items: [
            MenuItem(name: 'كريب جمبرى', prices: {'عادي': 150}),
            MenuItem(name: 'كريب سي فود', prices: {'عادي': 185}),
          ],
        ),
      ],
    ),
    MenuCategory(
      name: 'المكرونات',
      items: [
        MenuItem(name: 'مكرونة فرن', prices: {'عادي': 125}),
        MenuItem(name: 'مكرونة بولونيز', prices: {'عادي': 125}),
        MenuItem(name: 'مكرونة نجرسكو', prices: {'عادي': 140}),
        MenuItem(name: 'مكرونة سجق', prices: {'عادي': 125}),
        MenuItem(name: 'مكرونة بسطرمة', prices: {'عادي': 135}),
        MenuItem(name: 'مكرونة سوسيس', prices: {'عادي': 125}),
        MenuItem(name: 'مكرونة كرسبى', prices: {'عادي': 140}),
        MenuItem(name: 'مكرونة زنجر حار', prices: {'عادي': 150}),
        MenuItem(name: 'مكرونة جمبرى', prices: {'عادي': 160}),
        MenuItem(name: 'مكرونة سي فود', prices: {'عادي': 200}),
      ],
    ),
    MenuCategory(
      name: 'الحواوشي',
      items: [
        MenuItem(name: 'حواوشي سجق', prices: {'عادي': 120}),
        MenuItem(name: 'حواوشي بسطرمة', prices: {'عادي': 130}),
        MenuItem(name: 'حواوشي لحم مفروم', prices: {'عادي': 100}),
        MenuItem(name: 'وش بيتزا حسب الطلب', prices: {'عادي': 30}),
      ],
    ),
    MenuCategory(
      name: 'الإضافات والسلطات',
      items: [
        MenuItem(
          name: 'جبنة موتزاريلا إضافية',
          prices: {'وسط': 25, 'كبير': 50},
        ),
        MenuItem(name: 'إضافة لحوم', prices: {'وسط': 20, 'كبير': 40}),
        MenuItem(name: 'إضافة دجاج', prices: {'وسط': 30, 'كبير': 60}),
        MenuItem(name: 'إضافة أسماك', prices: {'وسط': 50, 'كبير': 100}),
        MenuItem(name: 'سلطة ثومية', prices: {'عادي': 15}),
        MenuItem(name: 'سلطة طحينة', prices: {'عادي': 15}),
        MenuItem(name: 'سلطة خضراء', prices: {'عادي': 10}),
      ],
    ),
    MenuCategory(
      name: 'الكشري',
      items: [
        MenuItem(
          name: 'كشري',
          prices: {'30': 30, '40': 40, '50': 50, '60': 60},
        ),
        MenuItem(name: 'كشري بالكبده', prices: {'75': 75, '100': 100}),
      ],
    ),
    MenuCategory(
      name: 'الطواجن',
      items: [
        MenuItem(name: 'طاجن خضار', prices: {'طاجن': 50}),
        MenuItem(name: 'طاجن كبده', prices: {'طاجن': 70}),
        MenuItem(name: 'طاجن سدق', prices: {'طاجن': 70}),
        MenuItem(name: 'طاجن فراخ', prices: {'طاجن': 80}),
        MenuItem(name: 'طاجن لحمه', prices: {'طاجن': 80}),
      ],
    ),
    MenuCategory(name: customCategoryName, isCustom: true),
  ];
}
