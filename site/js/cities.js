// Cities the page can work out a day for without asking anyone anything.
// The first city listed for a time zone is the one guessed from the
// visitor's clock. name | country | latitude | longitude | IANA zone

const RAW = `
Makkah|SA|21.4225|39.8262|Asia/Riyadh
Madinah|SA|24.4672|39.6112|Asia/Riyadh
Riyadh|SA|24.7136|46.6753|Asia/Riyadh
Jeddah|SA|21.4858|39.1925|Asia/Riyadh
New York|US|40.7128|-74.0060|America/New_York
Washington|US|38.9072|-77.0369|America/New_York
Boston|US|42.3601|-71.0589|America/New_York
Philadelphia|US|39.9526|-75.1652|America/New_York
Atlanta|US|33.7490|-84.3880|America/New_York
Miami|US|25.7617|-80.1918|America/New_York
Detroit|US|42.3314|-83.0458|America/Detroit
Chicago|US|41.8781|-87.6298|America/Chicago
Houston|US|29.7604|-95.3698|America/Chicago
Dallas|US|32.7767|-96.7970|America/Chicago
Minneapolis|US|44.9778|-93.2650|America/Chicago
Denver|US|39.7392|-104.9903|America/Denver
Phoenix|US|33.4484|-112.0740|America/Phoenix
Los Angeles|US|34.0522|-118.2437|America/Los_Angeles
San Francisco|US|37.7749|-122.4194|America/Los_Angeles
Seattle|US|47.6062|-122.3321|America/Los_Angeles
Honolulu|US|21.3069|-157.8583|Pacific/Honolulu
Toronto|CA|43.6532|-79.3832|America/Toronto
Montréal|CA|45.5019|-73.5674|America/Toronto
Ottawa|CA|45.4215|-75.6972|America/Toronto
Winnipeg|CA|49.8951|-97.1384|America/Winnipeg
Calgary|CA|51.0447|-114.0719|America/Edmonton
Edmonton|CA|53.5461|-113.4938|America/Edmonton
Vancouver|CA|49.2827|-123.1207|America/Vancouver
Halifax|CA|44.6488|-63.5752|America/Halifax
Mexico City|MX|19.4326|-99.1332|America/Mexico_City
Bogotá|CO|4.7110|-74.0721|America/Bogota
Lima|PE|-12.0464|-77.0428|America/Lima
São Paulo|BR|-23.5505|-46.6333|America/Sao_Paulo
Buenos Aires|AR|-34.6037|-58.3816|America/Argentina/Buenos_Aires
Santiago|CL|-33.4489|-70.6693|America/Santiago
Port of Spain|TT|10.6549|-61.5019|America/Port_of_Spain
Georgetown|GY|6.8013|-58.1551|America/Guyana
Paramaribo|SR|5.8520|-55.2038|America/Paramaribo
London|GB|51.5074|-0.1278|Europe/London
Birmingham|GB|52.4862|-1.8904|Europe/London
Manchester|GB|53.4808|-2.2426|Europe/London
Bradford|GB|53.7960|-1.7594|Europe/London
Glasgow|GB|55.8642|-4.2518|Europe/London
Dublin|IE|53.3498|-6.2603|Europe/Dublin
Paris|FR|48.8566|2.3522|Europe/Paris
Marseille|FR|43.2965|5.3698|Europe/Paris
Brussels|BE|50.8503|4.3517|Europe/Brussels
Amsterdam|NL|52.3676|4.9041|Europe/Amsterdam
Berlin|DE|52.5200|13.4050|Europe/Berlin
Frankfurt|DE|50.1109|8.6821|Europe/Berlin
Cologne|DE|50.9375|6.9603|Europe/Berlin
Vienna|AT|48.2082|16.3738|Europe/Vienna
Zürich|CH|47.3769|8.5417|Europe/Zurich
Madrid|ES|40.4168|-3.7038|Europe/Madrid
Barcelona|ES|41.3874|2.1686|Europe/Madrid
Lisbon|PT|38.7223|-9.1393|Europe/Lisbon
Rome|IT|41.9028|12.4964|Europe/Rome
Milan|IT|45.4642|9.1900|Europe/Rome
Copenhagen|DK|55.6761|12.5683|Europe/Copenhagen
Stockholm|SE|59.3293|18.0686|Europe/Stockholm
Oslo|NO|59.9139|10.7522|Europe/Oslo
Helsinki|FI|60.1699|24.9384|Europe/Helsinki
Warsaw|PL|52.2297|21.0122|Europe/Warsaw
Prague|CZ|50.0755|14.4378|Europe/Prague
Budapest|HU|47.4979|19.0402|Europe/Budapest
Athens|GR|37.9838|23.7275|Europe/Athens
Sarajevo|BA|43.8563|18.4131|Europe/Sarajevo
Tirana|AL|41.3275|19.8187|Europe/Tirane
Belgrade|RS|44.7866|20.4489|Europe/Belgrade
Pristina|XK|42.6629|21.1655|Europe/Belgrade
Skopje|MK|41.9981|21.4254|Europe/Skopje
Sofia|BG|42.6977|23.3219|Europe/Sofia
Bucharest|RO|44.4268|26.1025|Europe/Bucharest
Kyiv|UA|50.4501|30.5234|Europe/Kyiv
Istanbul|TR|41.0082|28.9784|Europe/Istanbul
Ankara|TR|39.9334|32.8597|Europe/Istanbul
Moscow|RU|55.7558|37.6173|Europe/Moscow
Kazan|RU|55.7961|49.1064|Europe/Moscow
Cairo|EG|30.0444|31.2357|Africa/Cairo
Alexandria|EG|31.2001|29.9187|Africa/Cairo
Casablanca|MA|33.5731|-7.5898|Africa/Casablanca
Rabat|MA|34.0209|-6.8416|Africa/Casablanca
Algiers|DZ|36.7538|3.0588|Africa/Algiers
Tunis|TN|36.8065|10.1815|Africa/Tunis
Tripoli|LY|32.8872|13.1913|Africa/Tripoli
Khartoum|SD|15.5007|32.5599|Africa/Khartoum
Lagos|NG|6.5244|3.3792|Africa/Lagos
Kano|NG|12.0022|8.5920|Africa/Lagos
Abuja|NG|9.0765|7.3986|Africa/Lagos
Accra|GH|5.6037|-0.1870|Africa/Accra
Dakar|SN|14.7167|-17.4677|Africa/Dakar
Bamako|ML|12.6392|-8.0029|Africa/Bamako
Abidjan|CI|5.3600|-4.0083|Africa/Abidjan
Nairobi|KE|-1.2921|36.8219|Africa/Nairobi
Mombasa|KE|-4.0435|39.6682|Africa/Nairobi
Addis Ababa|ET|9.0054|38.7636|Africa/Addis_Ababa
Mogadishu|SO|2.0469|45.3182|Africa/Mogadishu
Dar es Salaam|TZ|-6.7924|39.2083|Africa/Dar_es_Salaam
Kampala|UG|0.3476|32.5825|Africa/Kampala
Johannesburg|ZA|-26.2041|28.0473|Africa/Johannesburg
Cape Town|ZA|-33.9249|18.4241|Africa/Johannesburg
Durban|ZA|-29.8587|31.0218|Africa/Johannesburg
Dubai|AE|25.2048|55.2708|Asia/Dubai
Abu Dhabi|AE|24.4539|54.3773|Asia/Dubai
Doha|QA|25.2854|51.5310|Asia/Qatar
Kuwait City|KW|29.3759|47.9774|Asia/Kuwait
Manama|BH|26.2285|50.5860|Asia/Bahrain
Muscat|OM|23.5880|58.3829|Asia/Muscat
Sanaa|YE|15.3694|44.1910|Asia/Aden
Baghdad|IQ|33.3152|44.3661|Asia/Baghdad
Tehran|IR|35.6892|51.3890|Asia/Tehran
Amman|JO|31.9454|35.9284|Asia/Amman
Beirut|LB|33.8938|35.5018|Asia/Beirut
Damascus|SY|33.5138|36.2765|Asia/Damascus
Jerusalem|PS|31.7683|35.2137|Asia/Jerusalem
Gaza|PS|31.5017|34.4668|Asia/Gaza
Hebron|PS|31.5326|35.0998|Asia/Hebron
Baku|AZ|40.4093|49.8671|Asia/Baku
Karachi|PK|24.8607|67.0011|Asia/Karachi
Lahore|PK|31.5204|74.3587|Asia/Karachi
Islamabad|PK|33.6844|73.0479|Asia/Karachi
Kabul|AF|34.5553|69.2075|Asia/Kabul
Tashkent|UZ|41.2995|69.2401|Asia/Tashkent
Almaty|KZ|43.2220|76.8512|Asia/Almaty
Delhi|IN|28.6139|77.2090|Asia/Kolkata
Mumbai|IN|19.0760|72.8777|Asia/Kolkata
Hyderabad|IN|17.3850|78.4867|Asia/Kolkata
Bengaluru|IN|12.9716|77.5946|Asia/Kolkata
Kolkata|IN|22.5726|88.3639|Asia/Kolkata
Dhaka|BD|23.8103|90.4125|Asia/Dhaka
Colombo|LK|6.9271|79.8612|Asia/Colombo
Malé|MV|4.1755|73.5093|Indian/Maldives
Kathmandu|NP|27.7172|85.3240|Asia/Kathmandu
Jakarta|ID|-6.2088|106.8456|Asia/Jakarta
Surabaya|ID|-7.2575|112.7521|Asia/Jakarta
Kuala Lumpur|MY|3.1390|101.6869|Asia/Kuala_Lumpur
Singapore|SG|1.3521|103.8198|Asia/Singapore
Bandar Seri Begawan|BN|4.9031|114.9398|Asia/Brunei
Bangkok|TH|13.7563|100.5018|Asia/Bangkok
Manila|PH|14.5995|120.9842|Asia/Manila
Ho Chi Minh City|VN|10.8231|106.6297|Asia/Ho_Chi_Minh
Hong Kong|HK|22.3193|114.1694|Asia/Hong_Kong
Beijing|CN|39.9042|116.4074|Asia/Shanghai
Ürümqi|CN|43.8256|87.6168|Asia/Urumqi
Tokyo|JP|35.6762|139.6503|Asia/Tokyo
Seoul|KR|37.5665|126.9780|Asia/Seoul
Sydney|AU|-33.8688|151.2093|Australia/Sydney
Melbourne|AU|-37.8136|144.9631|Australia/Melbourne
Brisbane|AU|-27.4698|153.0251|Australia/Brisbane
Adelaide|AU|-34.9285|138.6007|Australia/Adelaide
Perth|AU|-31.9505|115.8605|Australia/Perth
Auckland|NZ|-36.8509|174.7645|Pacific/Auckland
`;

export const CITIES = RAW.trim().split('\n').map(line => {
  const [name, cc, lat, lon, tz] = line.split('|');
  return { name, cc, lat: Number(lat), lon: Number(lon), tz };
});

// Browsers still report some zones under their older names.
const ALIAS = {
  'Asia/Calcutta': 'Asia/Kolkata', 'Asia/Saigon': 'Asia/Ho_Chi_Minh', 'Europe/Kiev': 'Europe/Kyiv',
  'America/Buenos_Aires': 'America/Argentina/Buenos_Aires', 'Asia/Katmandu': 'Asia/Kathmandu',
  'Asia/Dacca': 'Asia/Dhaka', 'America/Montreal': 'America/Toronto', 'US/Eastern': 'America/New_York',
  'US/Central': 'America/Chicago', 'US/Mountain': 'America/Denver', 'US/Pacific': 'America/Los_Angeles',
  'Asia/Istanbul': 'Europe/Istanbul', 'America/Indiana/Indianapolis': 'America/New_York',
  'America/Indianapolis': 'America/New_York', 'America/Kentucky/Louisville': 'America/New_York',
  'America/Boise': 'America/Denver', 'America/Regina': 'America/Winnipeg', 'Asia/Hebron': 'Asia/Hebron',
  'Europe/Zagreb': 'Europe/Sarajevo', 'Europe/Ljubljana': 'Europe/Sarajevo', 'Europe/Podgorica': 'Europe/Belgrade',
  'Europe/Luxembourg': 'Europe/Brussels', 'Asia/Aden': 'Asia/Aden', 'Asia/Jayapura': 'Asia/Jakarta',
  'Asia/Makassar': 'Asia/Jakarta', 'Asia/Pontianak': 'Asia/Jakarta', 'Asia/Kuching': 'Asia/Kuala_Lumpur',
  'Africa/Nouakchott': 'Africa/Dakar', 'Africa/Banjul': 'Africa/Dakar', 'Africa/Conakry': 'Africa/Dakar',
  'Africa/Niamey': 'Africa/Lagos', 'Africa/Ndjamena': 'Africa/Lagos', 'Africa/Djibouti': 'Africa/Mogadishu',
  'Asia/Samarkand': 'Asia/Tashkent', 'Asia/Dushanbe': 'Asia/Tashkent', 'Asia/Bishkek': 'Asia/Almaty',
  'Asia/Ashgabat': 'Asia/Tashkent', 'Asia/Thimphu': 'Asia/Dhaka', 'Asia/Yangon': 'Asia/Bangkok',
};

/** The city for the visitor's clock. Reads the browser's time zone and nothing else. */
export function guessCity() {
  let tz = 'Asia/Riyadh';
  try { tz = Intl.DateTimeFormat().resolvedOptions().timeZone || tz; } catch { /* keep the default */ }
  tz = ALIAS[tz] || tz;
  const direct = CITIES.find(c => c.tz === tz);
  if (direct) return { city: direct, guessed: true };

  // An unlisted zone: fall back to a listed city keeping the same clock time right now.
  const now = Date.now();
  const offset = z => {
    try {
      const parts = new Intl.DateTimeFormat('en-US', { timeZone: z, hourCycle: 'h23', hour: 'numeric', minute: 'numeric', day: 'numeric' }).formatToParts(now);
      const get = t => Number(parts.find(p => p.type === t).value);
      return get('day') * 1440 + get('hour') * 60 + get('minute');
    } catch { return NaN; }
  };
  const mine = offset(tz);
  const same = CITIES.find(c => offset(c.tz) === mine);
  return { city: same || CITIES[0], guessed: Boolean(same) };
}

// The method a region's timetables commonly use: the same starting point
// the app offers (CalculationMethodChoice.commonMethod(forCountryCode:)).
const METHOD_BY_COUNTRY = {
  US: 'NorthAmerica', CA: 'NorthAmerica', AE: 'Dubai', QA: 'Qatar', KW: 'Kuwait',
  SG: 'Singapore', MY: 'Singapore', BN: 'Singapore', ID: 'Singapore', IR: 'Tehran', TR: 'Turkey',
  PK: 'Karachi', BD: 'Karachi', IN: 'Karachi', AF: 'Karachi', LK: 'Karachi',
  EG: 'Egyptian', SD: 'Egyptian', LY: 'Egyptian', DZ: 'Egyptian', TN: 'Egyptian', MA: 'Egyptian',
  SA: 'UmmAlQura', YE: 'UmmAlQura', BH: 'UmmAlQura', OM: 'UmmAlQura',
};
const METHOD_NAME = {
  NorthAmerica: 'North America (ISNA)', Dubai: 'Dubai', Qatar: 'Qatar', Kuwait: 'Kuwait',
  Singapore: 'MUIS, Singapore', Tehran: 'Institute of Geophysics, Tehran', Turkey: 'Diyanet',
  Karachi: 'University of Islamic Sciences, Karachi', Egyptian: 'Egyptian General Authority of Survey',
  UmmAlQura: 'Umm al-Qura', MuslimWorldLeague: 'Muslim World League',
};
export const methodFor = cc => METHOD_BY_COUNTRY[cc] || 'MuslimWorldLeague';
export const methodName = key => METHOD_NAME[key] || key;
