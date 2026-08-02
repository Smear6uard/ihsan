# ADHKĀR — REVIEW REQUEST

**Status: DRAFT — PENDING SCHOLAR REVIEW.**

This document is generated from the app's single content file,
`Packages/IhsanCore/Sources/IhsanCore/Resources/adhkar-content.json`
(schema 1, content 2026.08.02-draft.1). It is the complete set of
religious text Ihsan is able to display. There is no other source:
no network fetch, no generated text, no fallback strings. The
on-device model never touches any of it.

## What is being asked

Please read each item below and check its box when you are satisfied
with **all four** of:

1. **Arabic** — orthography and tashkeel as transmitted.
2. **Translation** — faithful, not interpretive beyond necessity.
3. **Source** — collection and number correct, and the report sound
   enough to be offered as a daily practice.
4. **Count** — the transmitted repetition, where one is transmitted.

Items whose reference carries a `verify reference` warning were
transcribed with the wording confident but the collection number
uncertain. Those numbers need checking against a printed copy before
anything ships.

## How the app uses this

- Each set is offered only inside its own time window (morning:
  Fajr→sunrise, extending into mid-morning; evening: ʿAṣr→Maghrib,
  optionally into the early night; after-prayer: from a logged
  prayer; before sleep: after ʿIshāʾ is logged). There is no search,
  no browse-all list, no library.
- Items are counted on the app's existing dhikr instrument. Sessions
  are recorded as plain facts — no streaks, no scores, no percentages.
- The occasioned duas at the end are carried in the file and reviewed
  here, but **no surface in this build offers them**. They are
  reviewed now so that a future occasioned surface starts from vetted
  text.

## Editorial decisions taken (please confirm or correct)

- **Honorifics.** The editorial ﷺ that printed compilations insert
  after the Prophet's name inside a duʿāʾ text has been omitted, so
  that only the transmitted words of the duʿāʾ appear. This affects
  *Raḍītu bi'llāhi Rabban*.
- **Verse numbering.** Qurʾānic passages are set as continuous
  recitation without ornate verse markers, since these are recited as
  remembrance rather than read from a muṣḥaf. Pause marks (ۖ ۗ ۚ) are
  kept.
- **Basmala.** The three Quls are given with the basmala, as they are
  recited. Āyat al-Kursī and the closing verses of al-Baqarah are
  given without it, as they are mid-sūrah.
- **Orthography.** Qurʾānic text follows the common printed ʿUthmānī
  form; ḥadīth text follows standard modern orthography with full
  tashkeel. This mixed convention matches how Ḥiṣn al-Muslim and
  similar compilations are typeset.
- **Transliteration** is provided as a pronunciation aid only and is
  collapsible in the app's settings.

## The gate

The app will not show any of this in a release build while the
content file reads `"reviewStatus": "draft"`. `AdhkarAvailability`
enforces it in code, and `AdhkarReviewGateTests` enforces that the
enforcement exists. When this document is signed, the maintainer
changes that one field to `"reviewed"`.

---


## Contents

- **Morning set** — 16 items
- **Evening set** — 16 items
- **After each prayer** — 10 items
- **Before sleep** — 7 items
- **Occasioned duas (no surface in this build)** — 8 items

**Total: 57 items.** 23 carry a reference to verify.


## Morning set

### 1. `morning.ayat-al-kursi`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ

**Transliteration.** Allāhu lā ilāha illā huwa'l-Ḥayyu'l-Qayyūm. Lā ta'khudhuhu sinatun wa lā nawm. Lahu mā fi's-samāwāti wa mā fi'l-arḍ. Man dha'lladhī yashfaʿu ʿindahu illā bi-idhnih. Yaʿlamu mā bayna aydīhim wa mā khalfahum. Wa lā yuḥīṭūna bi-shay'in min ʿilmihi illā bimā shā'. Wasiʿa kursiyyuhu's-samāwāti wa'l-arḍ. Wa lā ya'ūduhu ḥifẓuhumā. Wa huwa'l-ʿAliyyu'l-ʿAẓīm.

**Translation.** Allah — there is no god but He, the Ever-Living, the Sustainer of all. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what lies before them and what lies behind them, and they encompass nothing of His knowledge except what He wills. His Seat extends over the heavens and the earth, and their preservation does not weary Him. And He is the Most High, the Most Great.

**Source.** Qur'an — al-Baqarah 2:255

**Count.** once

### 2. `morning.al-ikhlas`

- [ ] Arabic, translation, source, and count are all correct.

> بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ قُلْ هُوَ اللَّهُ أَحَدٌ اللَّهُ الصَّمَدُ لَمْ يَلِدْ وَلَمْ يُولَدْ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ

**Transliteration.** Bismi'llāhi'r-Raḥmāni'r-Raḥīm. Qul huwa'llāhu aḥad. Allāhu'ṣ-Ṣamad. Lam yalid wa lam yūlad. Wa lam yakun lahu kufuwan aḥad.

**Translation.** In the name of Allah, the Most Merciful, the Especially Merciful. Say: He is Allah, One. Allah, the Eternal Refuge. He neither begets nor is born, and there is none comparable to Him.

**Source.** Qur'an — al-Ikhlāṣ 112:1–4

**Count.** ×3

### 3. `morning.al-falaq`

- [ ] Arabic, translation, source, and count are all correct.

> بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ مِن شَرِّ مَا خَلَقَ وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ

**Transliteration.** Bismi'llāhi'r-Raḥmāni'r-Raḥīm. Qul aʿūdhu bi-Rabbi'l-falaq. Min sharri mā khalaq. Wa min sharri ghāsiqin idhā waqab. Wa min sharri'n-naffāthāti fi'l-ʿuqad. Wa min sharri ḥāsidin idhā ḥasad.

**Translation.** In the name of Allah, the Most Merciful, the Especially Merciful. Say: I seek refuge in the Lord of the daybreak, from the evil of what He has created, and from the evil of darkness when it settles, and from the evil of those who blow upon knots, and from the evil of an envier when he envies.

**Source.** Qur'an — al-Falaq 113:1–5

**Count.** ×3

### 4. `morning.an-nas`

- [ ] Arabic, translation, source, and count are all correct.

> بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ قُلْ أَعُوذُ بِرَبِّ النَّاسِ مَلِكِ النَّاسِ إِلَٰهِ النَّاسِ مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ مِنَ الْجِنَّةِ وَالنَّاسِ

**Transliteration.** Bismi'llāhi'r-Raḥmāni'r-Raḥīm. Qul aʿūdhu bi-Rabbi'n-nās. Maliki'n-nās. Ilāhi'n-nās. Min sharri'l-waswāsi'l-khannās. Alladhī yuwaswisu fī ṣudūri'n-nās. Mina'l-jinnati wa'n-nās.

**Translation.** In the name of Allah, the Most Merciful, the Especially Merciful. Say: I seek refuge in the Lord of mankind, the Sovereign of mankind, the God of mankind, from the evil of the retreating whisperer who whispers in the breasts of mankind — from among the jinn and mankind.

**Source.** Qur'an — an-Nās 114:1–6

**Count.** ×3

### 5. `morning.sayyid-al-istighfar`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَٰهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَىٰ عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ

**Transliteration.** Allāhumma anta Rabbī, lā ilāha illā ant. Khalaqtanī wa anā ʿabduk, wa anā ʿalā ʿahdika wa waʿdika ma'staṭaʿt. Aʿūdhu bika min sharri mā ṣanaʿt. Abū'u laka bi-niʿmatika ʿalayy, wa abū'u bi-dhanbī fa'ghfir lī fa-innahu lā yaghfiru'dh-dhunūba illā ant.

**Translation.** O Allah, You are my Lord; there is no god but You. You created me and I am Your servant, and I hold to Your covenant and Your promise as much as I am able. I seek refuge in You from the evil of what I have done. I acknowledge Your favour upon me and I acknowledge my sin, so forgive me — for none forgives sins but You.

**Source.** al-Bukhārī — 6306

**Count.** once

### 6. `morning.asbahna-wal-mulk`

- [ ] Arabic, translation, source, and count are all correct.

> أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ. رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَٰذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَٰذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ

**Transliteration.** Aṣbaḥnā wa aṣbaḥa'l-mulku li'llāh, wa'l-ḥamdu li'llāh, lā ilāha illa'llāhu waḥdahu lā sharīka lah, lahu'l-mulku wa lahu'l-ḥamdu wa huwa ʿalā kulli shay'in qadīr. Rabbi as'aluka khayra mā fī hādha'l-yawmi wa khayra mā baʿdah, wa aʿūdhu bika min sharri mā fī hādha'l-yawmi wa sharri mā baʿdah. Rabbi aʿūdhu bika mina'l-kasali wa sū'i'l-kibar. Rabbi aʿūdhu bika min ʿadhābin fi'n-nāri wa ʿadhābin fi'l-qabr.

**Translation.** We have entered the morning and the dominion has entered the morning belonging to Allah, and all praise is for Allah. There is no god but Allah alone, without partner; His is the dominion and His is the praise, and He is over all things capable. My Lord, I ask You for the good of this day and the good of what follows it, and I seek refuge in You from the evil of this day and the evil of what follows it. My Lord, I seek refuge in You from idleness and from the misery of old age. My Lord, I seek refuge in You from punishment in the Fire and punishment in the grave.

**Source.** Muslim — 2723

**Count.** once

### 7. `morning.allahumma-bika-asbahna`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ

**Transliteration.** Allāhumma bika aṣbaḥnā, wa bika amsaynā, wa bika naḥyā, wa bika namūt, wa ilayka'n-nushūr.

**Translation.** O Allah, by You we enter the morning and by You we enter the evening; by You we live and by You we die, and to You is the resurrection.

**Source.** Abū Dāwūd; al-Tirmidhī — Abū Dāwūd 5068; al-Tirmidhī 3391  **⚠ verify reference**

**Count.** once

### 8. `morning.ma-asbaha-bi-min-nimah`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُمَّ مَا أَصْبَحَ بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ

**Transliteration.** Allāhumma mā aṣbaḥa bī min niʿmatin aw bi-aḥadin min khalqik, fa-minka waḥdaka lā sharīka lak, fa-laka'l-ḥamdu wa laka'sh-shukr.

**Translation.** O Allah, whatever favour has come to me this morning, or to any of Your creation, is from You alone, without partner. So Yours is the praise and Yours is the thanks.

**Source.** Abū Dāwūd — 5073  **⚠ verify reference**

**Count.** once

### 9. `morning.raditu-billahi-rabban`

- [ ] Arabic, translation, source, and count are all correct.

> رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ نَبِيًّا

**Transliteration.** Raḍītu bi'llāhi Rabban, wa bi'l-Islāmi dīnan, wa bi-Muḥammadin nabiyyan.

**Translation.** I am content with Allah as Lord, with Islam as religion, and with Muhammad as Prophet.

**Source.** Abū Dāwūd; al-Tirmidhī — Abū Dāwūd 5072; al-Tirmidhī 3389  **⚠ verify reference**

**Count.** ×3

### 10. `morning.ya-hayyu-ya-qayyum`

- [ ] Arabic, translation, source, and count are all correct.

> يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ، وَلَا تَكِلْنِي إِلَىٰ نَفْسِي طَرْفَةَ عَيْنٍ

**Transliteration.** Yā Ḥayyu yā Qayyūm, bi-raḥmatika astaghīth. Aṣliḥ lī sha'nī kullah, wa lā takilnī ilā nafsī ṭarfata ʿayn.

**Translation.** O Ever-Living, O Sustainer of all, by Your mercy I seek help. Set right all of my affairs, and do not entrust me to myself for the blink of an eye.

**Source.** al-Nasā'ī, ʿAmal al-Yawm wa'l-Layla; al-Ḥākim — al-Ḥākim 1/545  **⚠ verify reference**

**Count.** once

### 11. `morning.fitrat-al-islam`

- [ ] Arabic, translation, source, and count are all correct.

> أَصْبَحْنَا عَلَىٰ فِطْرَةِ الْإِسْلَامِ، وَعَلَىٰ كَلِمَةِ الْإِخْلَاصِ، وَعَلَىٰ دِينِ نَبِيِّنَا مُحَمَّدٍ، وَعَلَىٰ مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ

**Transliteration.** Aṣbaḥnā ʿalā fiṭrati'l-Islām, wa ʿalā kalimati'l-ikhlāṣ, wa ʿalā dīni nabiyyinā Muḥammad, wa ʿalā millati abīnā Ibrāhīma ḥanīfan musliman wa mā kāna mina'l-mushrikīn.

**Translation.** We have entered the morning upon the natural way of Islam, upon the word of sincerity, upon the religion of our Prophet Muhammad, and upon the way of our father Ibrahim, who was upright, a Muslim, and was not among those who associate partners with Allah.

**Source.** Aḥmad, al-Musnad — 3/406–407  **⚠ verify reference**

**Count.** once

### 12. `morning.alim-al-ghayb`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُمَّ عَالِمَ الْغَيْبِ وَالشَّهَادَةِ، فَاطِرَ السَّمَاوَاتِ وَالْأَرْضِ، رَبَّ كُلِّ شَيْءٍ وَمَلِيكَهُ، أَشْهَدُ أَنْ لَا إِلَٰهَ إِلَّا أَنْتَ، أَعُوذُ بِكَ مِنْ شَرِّ نَفْسِي، وَمِنْ شَرِّ الشَّيْطَانِ وَشِرْكِهِ، وَأَنْ أَقْتَرِفَ عَلَىٰ نَفْسِي سُوءًا أَوْ أَجُرَّهُ إِلَىٰ مُسْلِمٍ

**Transliteration.** Allāhumma ʿĀlima'l-ghaybi wa'sh-shahādah, Fāṭira's-samāwāti wa'l-arḍ, Rabba kulli shay'in wa malīkah, ash-hadu an lā ilāha illā ant. Aʿūdhu bika min sharri nafsī, wa min sharri'sh-shayṭāni wa shirkih, wa an aqtarifa ʿalā nafsī sū'an aw ajurrahu ilā muslim.

**Translation.** O Allah, Knower of the unseen and the seen, Originator of the heavens and the earth, Lord and Sovereign of everything — I bear witness that there is no god but You. I seek refuge in You from the evil of my own self, and from the evil of Satan and his call to associate partners with You, and from bringing evil upon myself or drawing it upon a Muslim.

**Source.** Abū Dāwūd; al-Tirmidhī — Abū Dāwūd 5067; al-Tirmidhī 3392  **⚠ verify reference**

**Count.** once

### 13. `morning.bismillah-alladhi-la-yadurr`

- [ ] Arabic, translation, source, and count are all correct.

> بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ

**Transliteration.** Bismi'llāhi'lladhī lā yaḍurru maʿa'smihi shay'un fi'l-arḍi wa lā fi's-samā', wa huwa's-Samīʿu'l-ʿAlīm.

**Translation.** In the name of Allah, with whose name nothing on earth or in the heaven can cause harm, and He is the All-Hearing, the All-Knowing.

**Source.** Abū Dāwūd; al-Tirmidhī — Abū Dāwūd 5088; al-Tirmidhī 3388  **⚠ verify reference**

**Count.** ×3

### 14. `morning.audhu-bi-kalimatillah`

- [ ] Arabic, translation, source, and count are all correct.

> أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ

**Transliteration.** Aʿūdhu bi-kalimāti'llāhi't-tāmmāti min sharri mā khalaq.

**Translation.** I seek refuge in the perfect words of Allah from the evil of what He has created.

**Source.** Muslim — 2709

**Count.** ×3

### 15. `morning.subhanallahi-wa-bihamdih`

- [ ] Arabic, translation, source, and count are all correct.

> سُبْحَانَ اللَّهِ وَبِحَمْدِهِ

**Transliteration.** Subḥāna'llāhi wa bi-ḥamdih.

**Translation.** Glory is to Allah, and praise is His.

**Source.** Muslim — 2691

**Count.** ×100

### 16. `morning.la-ilaha-illallah-wahdah`

- [ ] Arabic, translation, source, and count are all correct.

> لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ

**Transliteration.** Lā ilāha illa'llāhu waḥdahu lā sharīka lah, lahu'l-mulku wa lahu'l-ḥamdu wa huwa ʿalā kulli shay'in qadīr.

**Translation.** There is no god but Allah alone, without partner. His is the dominion and His is the praise, and He is over all things capable.

**Source.** al-Bukhārī; Muslim — al-Bukhārī 6403; Muslim 2691  **⚠ verify reference**

**Count.** ×10


## Evening set

### 1. `evening.ayat-al-kursi`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ

**Transliteration.** Allāhu lā ilāha illā huwa'l-Ḥayyu'l-Qayyūm. Lā ta'khudhuhu sinatun wa lā nawm. Lahu mā fi's-samāwāti wa mā fi'l-arḍ. Man dha'lladhī yashfaʿu ʿindahu illā bi-idhnih. Yaʿlamu mā bayna aydīhim wa mā khalfahum. Wa lā yuḥīṭūna bi-shay'in min ʿilmihi illā bimā shā'. Wasiʿa kursiyyuhu's-samāwāti wa'l-arḍ. Wa lā ya'ūduhu ḥifẓuhumā. Wa huwa'l-ʿAliyyu'l-ʿAẓīm.

**Translation.** Allah — there is no god but He, the Ever-Living, the Sustainer of all. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what lies before them and what lies behind them, and they encompass nothing of His knowledge except what He wills. His Seat extends over the heavens and the earth, and their preservation does not weary Him. And He is the Most High, the Most Great.

**Source.** Qur'an — al-Baqarah 2:255

**Count.** once

### 2. `evening.al-ikhlas`

- [ ] Arabic, translation, source, and count are all correct.

> بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ قُلْ هُوَ اللَّهُ أَحَدٌ اللَّهُ الصَّمَدُ لَمْ يَلِدْ وَلَمْ يُولَدْ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ

**Transliteration.** Bismi'llāhi'r-Raḥmāni'r-Raḥīm. Qul huwa'llāhu aḥad. Allāhu'ṣ-Ṣamad. Lam yalid wa lam yūlad. Wa lam yakun lahu kufuwan aḥad.

**Translation.** In the name of Allah, the Most Merciful, the Especially Merciful. Say: He is Allah, One. Allah, the Eternal Refuge. He neither begets nor is born, and there is none comparable to Him.

**Source.** Qur'an — al-Ikhlāṣ 112:1–4

**Count.** ×3

### 3. `evening.al-falaq`

- [ ] Arabic, translation, source, and count are all correct.

> بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ مِن شَرِّ مَا خَلَقَ وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ

**Transliteration.** Bismi'llāhi'r-Raḥmāni'r-Raḥīm. Qul aʿūdhu bi-Rabbi'l-falaq. Min sharri mā khalaq. Wa min sharri ghāsiqin idhā waqab. Wa min sharri'n-naffāthāti fi'l-ʿuqad. Wa min sharri ḥāsidin idhā ḥasad.

**Translation.** In the name of Allah, the Most Merciful, the Especially Merciful. Say: I seek refuge in the Lord of the daybreak, from the evil of what He has created, and from the evil of darkness when it settles, and from the evil of those who blow upon knots, and from the evil of an envier when he envies.

**Source.** Qur'an — al-Falaq 113:1–5

**Count.** ×3

### 4. `evening.an-nas`

- [ ] Arabic, translation, source, and count are all correct.

> بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ قُلْ أَعُوذُ بِرَبِّ النَّاسِ مَلِكِ النَّاسِ إِلَٰهِ النَّاسِ مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ مِنَ الْجِنَّةِ وَالنَّاسِ

**Transliteration.** Bismi'llāhi'r-Raḥmāni'r-Raḥīm. Qul aʿūdhu bi-Rabbi'n-nās. Maliki'n-nās. Ilāhi'n-nās. Min sharri'l-waswāsi'l-khannās. Alladhī yuwaswisu fī ṣudūri'n-nās. Mina'l-jinnati wa'n-nās.

**Translation.** In the name of Allah, the Most Merciful, the Especially Merciful. Say: I seek refuge in the Lord of mankind, the Sovereign of mankind, the God of mankind, from the evil of the retreating whisperer who whispers in the breasts of mankind — from among the jinn and mankind.

**Source.** Qur'an — an-Nās 114:1–6

**Count.** ×3

### 5. `evening.sayyid-al-istighfar`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَٰهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَىٰ عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ

**Transliteration.** Allāhumma anta Rabbī, lā ilāha illā ant. Khalaqtanī wa anā ʿabduk, wa anā ʿalā ʿahdika wa waʿdika ma'staṭaʿt. Aʿūdhu bika min sharri mā ṣanaʿt. Abū'u laka bi-niʿmatika ʿalayy, wa abū'u bi-dhanbī fa'ghfir lī fa-innahu lā yaghfiru'dh-dhunūba illā ant.

**Translation.** O Allah, You are my Lord; there is no god but You. You created me and I am Your servant, and I hold to Your covenant and Your promise as much as I am able. I seek refuge in You from the evil of what I have done. I acknowledge Your favour upon me and I acknowledge my sin, so forgive me — for none forgives sins but You.

**Source.** al-Bukhārī — 6306

**Count.** once

### 6. `evening.amsayna-wal-mulk`

- [ ] Arabic, translation, source, and count are all correct.

> أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ. رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَٰذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَٰذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ

**Transliteration.** Amsaynā wa amsa'l-mulku li'llāh, wa'l-ḥamdu li'llāh, lā ilāha illa'llāhu waḥdahu lā sharīka lah, lahu'l-mulku wa lahu'l-ḥamdu wa huwa ʿalā kulli shay'in qadīr. Rabbi as'aluka khayra mā fī hādhihi'l-laylati wa khayra mā baʿdahā, wa aʿūdhu bika min sharri mā fī hādhihi'l-laylati wa sharri mā baʿdahā. Rabbi aʿūdhu bika mina'l-kasali wa sū'i'l-kibar. Rabbi aʿūdhu bika min ʿadhābin fi'n-nāri wa ʿadhābin fi'l-qabr.

**Translation.** We have entered the evening and the dominion has entered the evening belonging to Allah, and all praise is for Allah. There is no god but Allah alone, without partner; His is the dominion and His is the praise, and He is over all things capable. My Lord, I ask You for the good of this night and the good of what follows it, and I seek refuge in You from the evil of this night and the evil of what follows it. My Lord, I seek refuge in You from idleness and from the misery of old age. My Lord, I seek refuge in You from punishment in the Fire and punishment in the grave.

**Source.** Muslim — 2723

**Count.** once

### 7. `evening.allahumma-bika-amsayna`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ

**Transliteration.** Allāhumma bika amsaynā, wa bika aṣbaḥnā, wa bika naḥyā, wa bika namūt, wa ilayka'l-maṣīr.

**Translation.** O Allah, by You we enter the evening and by You we enter the morning; by You we live and by You we die, and to You is the return.

**Source.** Abū Dāwūd; al-Tirmidhī — Abū Dāwūd 5068; al-Tirmidhī 3391  **⚠ verify reference**

**Count.** once

### 8. `evening.ma-amsa-bi-min-nimah`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُمَّ مَا أَمْسَىٰ بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ

**Transliteration.** Allāhumma mā amsā bī min niʿmatin aw bi-aḥadin min khalqik, fa-minka waḥdaka lā sharīka lak, fa-laka'l-ḥamdu wa laka'sh-shukr.

**Translation.** O Allah, whatever favour has come to me this evening, or to any of Your creation, is from You alone, without partner. So Yours is the praise and Yours is the thanks.

**Source.** Abū Dāwūd — 5073  **⚠ verify reference**

**Count.** once

### 9. `evening.raditu-billahi-rabban`

- [ ] Arabic, translation, source, and count are all correct.

> رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ نَبِيًّا

**Transliteration.** Raḍītu bi'llāhi Rabban, wa bi'l-Islāmi dīnan, wa bi-Muḥammadin nabiyyan.

**Translation.** I am content with Allah as Lord, with Islam as religion, and with Muhammad as Prophet.

**Source.** Abū Dāwūd; al-Tirmidhī — Abū Dāwūd 5072; al-Tirmidhī 3389  **⚠ verify reference**

**Count.** ×3

### 10. `evening.ya-hayyu-ya-qayyum`

- [ ] Arabic, translation, source, and count are all correct.

> يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ، وَلَا تَكِلْنِي إِلَىٰ نَفْسِي طَرْفَةَ عَيْنٍ

**Transliteration.** Yā Ḥayyu yā Qayyūm, bi-raḥmatika astaghīth. Aṣliḥ lī sha'nī kullah, wa lā takilnī ilā nafsī ṭarfata ʿayn.

**Translation.** O Ever-Living, O Sustainer of all, by Your mercy I seek help. Set right all of my affairs, and do not entrust me to myself for the blink of an eye.

**Source.** al-Nasā'ī, ʿAmal al-Yawm wa'l-Layla; al-Ḥākim — al-Ḥākim 1/545  **⚠ verify reference**

**Count.** once

### 11. `evening.fitrat-al-islam`

- [ ] Arabic, translation, source, and count are all correct.

> أَمْسَيْنَا عَلَىٰ فِطْرَةِ الْإِسْلَامِ، وَعَلَىٰ كَلِمَةِ الْإِخْلَاصِ، وَعَلَىٰ دِينِ نَبِيِّنَا مُحَمَّدٍ، وَعَلَىٰ مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ

**Transliteration.** Amsaynā ʿalā fiṭrati'l-Islām, wa ʿalā kalimati'l-ikhlāṣ, wa ʿalā dīni nabiyyinā Muḥammad, wa ʿalā millati abīnā Ibrāhīma ḥanīfan musliman wa mā kāna mina'l-mushrikīn.

**Translation.** We have entered the evening upon the natural way of Islam, upon the word of sincerity, upon the religion of our Prophet Muhammad, and upon the way of our father Ibrahim, who was upright, a Muslim, and was not among those who associate partners with Allah.

**Source.** Aḥmad, al-Musnad — 3/406–407  **⚠ verify reference**

**Count.** once

### 12. `evening.alim-al-ghayb`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُمَّ عَالِمَ الْغَيْبِ وَالشَّهَادَةِ، فَاطِرَ السَّمَاوَاتِ وَالْأَرْضِ، رَبَّ كُلِّ شَيْءٍ وَمَلِيكَهُ، أَشْهَدُ أَنْ لَا إِلَٰهَ إِلَّا أَنْتَ، أَعُوذُ بِكَ مِنْ شَرِّ نَفْسِي، وَمِنْ شَرِّ الشَّيْطَانِ وَشِرْكِهِ، وَأَنْ أَقْتَرِفَ عَلَىٰ نَفْسِي سُوءًا أَوْ أَجُرَّهُ إِلَىٰ مُسْلِمٍ

**Transliteration.** Allāhumma ʿĀlima'l-ghaybi wa'sh-shahādah, Fāṭira's-samāwāti wa'l-arḍ, Rabba kulli shay'in wa malīkah, ash-hadu an lā ilāha illā ant. Aʿūdhu bika min sharri nafsī, wa min sharri'sh-shayṭāni wa shirkih, wa an aqtarifa ʿalā nafsī sū'an aw ajurrahu ilā muslim.

**Translation.** O Allah, Knower of the unseen and the seen, Originator of the heavens and the earth, Lord and Sovereign of everything — I bear witness that there is no god but You. I seek refuge in You from the evil of my own self, and from the evil of Satan and his call to associate partners with You, and from bringing evil upon myself or drawing it upon a Muslim.

**Source.** Abū Dāwūd; al-Tirmidhī — Abū Dāwūd 5067; al-Tirmidhī 3392  **⚠ verify reference**

**Count.** once

### 13. `evening.bismillah-alladhi-la-yadurr`

- [ ] Arabic, translation, source, and count are all correct.

> بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ

**Transliteration.** Bismi'llāhi'lladhī lā yaḍurru maʿa'smihi shay'un fi'l-arḍi wa lā fi's-samā', wa huwa's-Samīʿu'l-ʿAlīm.

**Translation.** In the name of Allah, with whose name nothing on earth or in the heaven can cause harm, and He is the All-Hearing, the All-Knowing.

**Source.** Abū Dāwūd; al-Tirmidhī — Abū Dāwūd 5088; al-Tirmidhī 3388  **⚠ verify reference**

**Count.** ×3

### 14. `evening.audhu-bi-kalimatillah`

- [ ] Arabic, translation, source, and count are all correct.

> أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ

**Transliteration.** Aʿūdhu bi-kalimāti'llāhi't-tāmmāti min sharri mā khalaq.

**Translation.** I seek refuge in the perfect words of Allah from the evil of what He has created.

**Source.** Muslim — 2709

**Count.** ×3

### 15. `evening.subhanallahi-wa-bihamdih`

- [ ] Arabic, translation, source, and count are all correct.

> سُبْحَانَ اللَّهِ وَبِحَمْدِهِ

**Transliteration.** Subḥāna'llāhi wa bi-ḥamdih.

**Translation.** Glory is to Allah, and praise is His.

**Source.** Muslim — 2691

**Count.** ×100

### 16. `evening.la-ilaha-illallah-wahdah`

- [ ] Arabic, translation, source, and count are all correct.

> لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ

**Transliteration.** Lā ilāha illa'llāhu waḥdahu lā sharīka lah, lahu'l-mulku wa lahu'l-ḥamdu wa huwa ʿalā kulli shay'in qadīr.

**Translation.** There is no god but Allah alone, without partner. His is the dominion and His is the praise, and He is over all things capable.

**Source.** al-Bukhārī; Muslim — al-Bukhārī 6403; Muslim 2691  **⚠ verify reference**

**Count.** ×10


## After each prayer

### 1. `postPrayer.astaghfirullah`

- [ ] Arabic, translation, source, and count are all correct.

> أَسْتَغْفِرُ اللَّهَ

**Transliteration.** Astaghfiru'llāh.

**Translation.** I seek Allah's forgiveness.

**Source.** Muslim — 591

**Count.** ×3

### 2. `postPrayer.allahumma-anta-as-salam`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُمَّ أَنْتَ السَّلَامُ، وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ

**Transliteration.** Allāhumma anta's-Salām, wa minka's-salām, tabārakta yā Dha'l-Jalāli wa'l-Ikrām.

**Translation.** O Allah, You are Peace and from You comes peace. Blessed are You, Owner of Majesty and Honour.

**Source.** Muslim — 591

**Count.** once

### 3. `postPrayer.la-ilaha-illallah-la-mania`

- [ ] Arabic, translation, source, and count are all correct.

> لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ، اللَّهُمَّ لَا مَانِعَ لِمَا أَعْطَيْتَ، وَلَا مُعْطِيَ لِمَا مَنَعْتَ، وَلَا يَنْفَعُ ذَا الْجَدِّ مِنْكَ الْجَدُّ

**Transliteration.** Lā ilāha illa'llāhu waḥdahu lā sharīka lah, lahu'l-mulku wa lahu'l-ḥamdu wa huwa ʿalā kulli shay'in qadīr. Allāhumma lā māniʿa limā aʿṭayt, wa lā muʿṭiya limā manaʿt, wa lā yanfaʿu dha'l-jaddi minka'l-jadd.

**Translation.** There is no god but Allah alone, without partner. His is the dominion and His is the praise, and He is over all things capable. O Allah, none can withhold what You have given, and none can give what You have withheld, and no fortune can avail its owner against You.

**Source.** al-Bukhārī; Muslim — al-Bukhārī 844; Muslim 593

**Count.** once

### 4. `postPrayer.la-hawla-wa-la-quwwata`

- [ ] Arabic, translation, source, and count are all correct.

> لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ، لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ، لَا إِلَٰهَ إِلَّا اللَّهُ، وَلَا نَعْبُدُ إِلَّا إِيَّاهُ، لَهُ النِّعْمَةُ وَلَهُ الْفَضْلُ وَلَهُ الثَّنَاءُ الْحَسَنُ، لَا إِلَٰهَ إِلَّا اللَّهُ مُخْلِصِينَ لَهُ الدِّينَ وَلَوْ كَرِهَ الْكَافِرُونَ

**Transliteration.** Lā ilāha illa'llāhu waḥdahu lā sharīka lah, lahu'l-mulku wa lahu'l-ḥamdu wa huwa ʿalā kulli shay'in qadīr. Lā ḥawla wa lā quwwata illā bi'llāh. Lā ilāha illa'llāh, wa lā naʿbudu illā iyyāh. Lahu'n-niʿmatu wa lahu'l-faḍlu wa lahu'th-thanā'u'l-ḥasan. Lā ilāha illa'llāhu mukhliṣīna lahu'd-dīna wa law kariha'l-kāfirūn.

**Translation.** There is no god but Allah alone, without partner. His is the dominion and His is the praise, and He is over all things capable. There is no power and no strength except by Allah. There is no god but Allah, and we worship none but Him. His is the favour, His is the bounty, and His is the beautiful praise. There is no god but Allah, sincere to Him in religion, even if the disbelievers dislike it.

**Source.** Muslim — 594

**Count.** once

### 5. `postPrayer.allahumma-ainni-ala-dhikrik`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُمَّ أَعِنِّي عَلَىٰ ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ

**Transliteration.** Allāhumma aʿinnī ʿalā dhikrika wa shukrika wa ḥusni ʿibādatik.

**Translation.** O Allah, help me to remember You, to thank You, and to worship You well.

**Source.** Abū Dāwūd — 1522  **⚠ verify reference**

**Count.** once

### 6. `postPrayer.ayat-al-kursi`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ

**Transliteration.** Allāhu lā ilāha illā huwa'l-Ḥayyu'l-Qayyūm. Lā ta'khudhuhu sinatun wa lā nawm. Lahu mā fi's-samāwāti wa mā fi'l-arḍ. Man dha'lladhī yashfaʿu ʿindahu illā bi-idhnih. Yaʿlamu mā bayna aydīhim wa mā khalfahum. Wa lā yuḥīṭūna bi-shay'in min ʿilmihi illā bimā shā'. Wasiʿa kursiyyuhu's-samāwāti wa'l-arḍ. Wa lā ya'ūduhu ḥifẓuhumā. Wa huwa'l-ʿAliyyu'l-ʿAẓīm.

**Translation.** Allah — there is no god but He, the Ever-Living, the Sustainer of all. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what lies before them and what lies behind them, and they encompass nothing of His knowledge except what He wills. His Seat extends over the heavens and the earth, and their preservation does not weary Him. And He is the Most High, the Most Great.

**Source.** Qur'an, al-Baqarah 2:255; recited after each prayer per al-Nasā'ī, ʿAmal al-Yawm wa'l-Layla — al-Nasā'ī, ʿAmal al-Yawm wa'l-Layla 100  **⚠ verify reference**

**Count.** once

### 7. `postPrayer.subhanallah`

- [ ] Arabic, translation, source, and count are all correct.

> سُبْحَانَ اللَّهِ

**Transliteration.** Subḥāna'llāh.

**Translation.** Glory is to Allah.

**Source.** Muslim — 597

**Count.** ×33

### 8. `postPrayer.alhamdulillah`

- [ ] Arabic, translation, source, and count are all correct.

> الْحَمْدُ لِلَّهِ

**Transliteration.** Al-ḥamdu li'llāh.

**Translation.** All praise is for Allah.

**Source.** Muslim — 597

**Count.** ×33

### 9. `postPrayer.allahu-akbar`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُ أَكْبَرُ

**Transliteration.** Allāhu akbar.

**Translation.** Allah is the Greatest.

**Source.** Muslim — 597

**Count.** ×33

### 10. `postPrayer.completion-of-the-hundred`

- [ ] Arabic, translation, source, and count are all correct.

> لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ

**Transliteration.** Lā ilāha illa'llāhu waḥdahu lā sharīka lah, lahu'l-mulku wa lahu'l-ḥamdu wa huwa ʿalā kulli shay'in qadīr.

**Translation.** There is no god but Allah alone, without partner. His is the dominion and His is the praise, and He is over all things capable.

**Source.** Muslim — 597

**Count.** once

**Occasion.** Said once after the thirty-three of each, completing the hundred.


## Before sleep

### 1. `sleep.khawatim-al-baqarah`

- [ ] Arabic, translation, source, and count are all correct.

> آمَنَ الرَّسُولُ بِمَا أُنزِلَ إِلَيْهِ مِن رَّبِّهِ وَالْمُؤْمِنُونَ ۚ كُلٌّ آمَنَ بِاللَّهِ وَمَلَائِكَتِهِ وَكُتُبِهِ وَرُسُلِهِ لَا نُفَرِّقُ بَيْنَ أَحَدٍ مِّن رُّسُلِهِ ۚ وَقَالُوا سَمِعْنَا وَأَطَعْنَا ۖ غُفْرَانَكَ رَبَّنَا وَإِلَيْكَ الْمَصِيرُ لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا ۚ لَهَا مَا كَسَبَتْ وَعَلَيْهَا مَا اكْتَسَبَتْ ۗ رَبَّنَا لَا تُؤَاخِذْنَا إِن نَّسِينَا أَوْ أَخْطَأْنَا ۚ رَبَّنَا وَلَا تَحْمِلْ عَلَيْنَا إِصْرًا كَمَا حَمَلْتَهُ عَلَى الَّذِينَ مِن قَبْلِنَا ۚ رَبَّنَا وَلَا تُحَمِّلْنَا مَا لَا طَاقَةَ لَنَا بِهِ ۖ وَاعْفُ عَنَّا وَاغْفِرْ لَنَا وَارْحَمْنَا ۚ أَنتَ مَوْلَانَا فَانصُرْنَا عَلَى الْقَوْمِ الْكَافِرِينَ

**Transliteration.** Āmana'r-Rasūlu bimā unzila ilayhi min Rabbihi wa'l-mu'minūn. Kullun āmana bi'llāhi wa malā'ikatihi wa kutubihi wa rusulih, lā nufarriqu bayna aḥadin min rusulih. Wa qālū samiʿnā wa aṭaʿnā, ghufrānaka Rabbanā wa ilayka'l-maṣīr. Lā yukallifu'llāhu nafsan illā wusʿahā, lahā mā kasabat wa ʿalayhā ma'ktasabat. Rabbanā lā tu'ākhidhnā in nasīnā aw akhṭa'nā. Rabbanā wa lā taḥmil ʿalaynā iṣran kamā ḥamaltahu ʿala'lladhīna min qablinā. Rabbanā wa lā tuḥammilnā mā lā ṭāqata lanā bih. Wa'ʿfu ʿannā wa'ghfir lanā wa'rḥamnā. Anta Mawlānā fa'nṣurnā ʿala'l-qawmi'l-kāfirīn.

**Translation.** The Messenger has believed in what was revealed to him from his Lord, and so have the believers. All of them have believed in Allah and His angels and His books and His messengers, saying: we make no distinction between any of His messengers. And they said: we hear and we obey. Grant us Your forgiveness, our Lord, and to You is the return. Allah does not charge a soul beyond its capacity. It has whatever good it has earned, and against it is whatever evil it has earned. Our Lord, do not take us to task if we forget or make a mistake. Our Lord, do not lay upon us a burden like the one You laid upon those before us. Our Lord, do not burden us with what we have no strength to bear. Pardon us, forgive us, and have mercy on us. You are our Protector, so give us victory over the disbelieving people.

**Source.** Qur'an, al-Baqarah 2:285–286; al-Bukhārī — al-Bukhārī 5009  **⚠ verify reference**

**Count.** once

### 2. `sleep.ayat-al-kursi`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ

**Transliteration.** Allāhu lā ilāha illā huwa'l-Ḥayyu'l-Qayyūm. Lā ta'khudhuhu sinatun wa lā nawm. Lahu mā fi's-samāwāti wa mā fi'l-arḍ. Man dha'lladhī yashfaʿu ʿindahu illā bi-idhnih. Yaʿlamu mā bayna aydīhim wa mā khalfahum. Wa lā yuḥīṭūna bi-shay'in min ʿilmihi illā bimā shā'. Wasiʿa kursiyyuhu's-samāwāti wa'l-arḍ. Wa lā ya'ūduhu ḥifẓuhumā. Wa huwa'l-ʿAliyyu'l-ʿAẓīm.

**Translation.** Allah — there is no god but He, the Ever-Living, the Sustainer of all. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what lies before them and what lies behind them, and they encompass nothing of His knowledge except what He wills. His Seat extends over the heavens and the earth, and their preservation does not weary Him. And He is the Most High, the Most Great.

**Source.** Qur'an, al-Baqarah 2:255; al-Bukhārī — al-Bukhārī 2311

**Count.** once

### 3. `sleep.bismika-rabbi-wadatu-janbi`

- [ ] Arabic, translation, source, and count are all correct.

> بِاسْمِكَ رَبِّي وَضَعْتُ جَنْبِي، وَبِكَ أَرْفَعُهُ، إِنْ أَمْسَكْتَ نَفْسِي فَارْحَمْهَا، وَإِنْ أَرْسَلْتَهَا فَاحْفَظْهَا بِمَا تَحْفَظُ بِهِ عِبَادَكَ الصَّالِحِينَ

**Transliteration.** Bi'smika Rabbī waḍaʿtu janbī, wa bika arfaʿuh. In amsakta nafsī fa'rḥamhā, wa in arsaltahā fa'ḥfaẓhā bimā taḥfaẓu bihi ʿibādaka'ṣ-ṣāliḥīn.

**Translation.** In Your name, my Lord, I lay down my side, and by You I raise it. If You take my soul, have mercy on it; and if You release it, protect it with that by which You protect Your righteous servants.

**Source.** al-Bukhārī; Muslim — al-Bukhārī 6320; Muslim 2714

**Count.** once

### 4. `sleep.allahumma-aslamtu-nafsi`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُمَّ أَسْلَمْتُ نَفْسِي إِلَيْكَ، وَفَوَّضْتُ أَمْرِي إِلَيْكَ، وَأَلْجَأْتُ ظَهْرِي إِلَيْكَ، رَغْبَةً وَرَهْبَةً إِلَيْكَ، لَا مَلْجَأَ وَلَا مَنْجَا مِنْكَ إِلَّا إِلَيْكَ، آمَنْتُ بِكِتَابِكَ الَّذِي أَنْزَلْتَ، وَبِنَبِيِّكَ الَّذِي أَرْسَلْتَ

**Transliteration.** Allāhumma aslamtu nafsī ilayk, wa fawwaḍtu amrī ilayk, wa alja'tu ẓahrī ilayk, raghbatan wa rahbatan ilayk. Lā malja'a wa lā manjā minka illā ilayk. Āmantu bi-kitābika'lladhī anzalt, wa bi-nabiyyika'lladhī arsalt.

**Translation.** O Allah, I have submitted myself to You, and entrusted my affair to You, and turned my back to You for support, out of hope in You and fear of You. There is no refuge and no escape from You except to You. I have believed in Your Book which You sent down, and in Your Prophet whom You sent.

**Source.** al-Bukhārī; Muslim — al-Bukhārī 247; Muslim 2710

**Count.** once

### 5. `sleep.subhanallah`

- [ ] Arabic, translation, source, and count are all correct.

> سُبْحَانَ اللَّهِ

**Transliteration.** Subḥāna'llāh.

**Translation.** Glory is to Allah.

**Source.** al-Bukhārī; Muslim — al-Bukhārī 5362; Muslim 2727

**Count.** ×33

### 6. `sleep.alhamdulillah`

- [ ] Arabic, translation, source, and count are all correct.

> الْحَمْدُ لِلَّهِ

**Transliteration.** Al-ḥamdu li'llāh.

**Translation.** All praise is for Allah.

**Source.** al-Bukhārī; Muslim — al-Bukhārī 5362; Muslim 2727

**Count.** ×33

### 7. `sleep.allahu-akbar`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُ أَكْبَرُ

**Transliteration.** Allāhu akbar.

**Translation.** Allah is the Greatest.

**Source.** al-Bukhārī; Muslim — al-Bukhārī 5362; Muslim 2727

**Count.** ×34


## Occasioned duas (no surface in this build)

### 1. `situational.waking`

- [ ] Arabic, translation, source, and count are all correct.

> الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ

**Transliteration.** Al-ḥamdu li'llāhi'lladhī aḥyānā baʿda mā amātanā wa ilayhi'n-nushūr.

**Translation.** All praise is for Allah, who gave us life after He caused us to die, and to Him is the resurrection.

**Source.** al-Bukhārī — 6312

**Count.** once

**Occasion.** On waking.

### 2. `situational.leaving-home`

- [ ] Arabic, translation, source, and count are all correct.

> بِسْمِ اللَّهِ، تَوَكَّلْتُ عَلَى اللَّهِ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ

**Transliteration.** Bismi'llāh, tawakkaltu ʿala'llāh, wa lā ḥawla wa lā quwwata illā bi'llāh.

**Translation.** In the name of Allah; I place my trust in Allah; there is no power and no strength except by Allah.

**Source.** Abū Dāwūd; al-Tirmidhī — Abū Dāwūd 5095; al-Tirmidhī 3426  **⚠ verify reference**

**Count.** once

**Occasion.** On leaving the house.

### 3. `situational.entering-home`

- [ ] Arabic, translation, source, and count are all correct.

> بِسْمِ اللَّهِ وَلَجْنَا، وَبِسْمِ اللَّهِ خَرَجْنَا، وَعَلَىٰ رَبِّنَا تَوَكَّلْنَا

**Transliteration.** Bismi'llāhi walajnā, wa bismi'llāhi kharajnā, wa ʿalā Rabbinā tawakkalnā.

**Translation.** In the name of Allah we enter, and in the name of Allah we leave, and upon our Lord we place our trust.

**Source.** Abū Dāwūd — 5096  **⚠ verify reference**

**Count.** once

**Occasion.** On entering the house.

### 4. `situational.before-eating`

- [ ] Arabic, translation, source, and count are all correct.

> بِسْمِ اللَّهِ

**Transliteration.** Bismi'llāh.

**Translation.** In the name of Allah.

**Source.** Abū Dāwūd; al-Tirmidhī — Abū Dāwūd 3767; al-Tirmidhī 1858  **⚠ verify reference**

**Count.** once

**Occasion.** Before eating. If it is forgotten at the start: Bismillāhi awwalahu wa ākhirah — in the name of Allah, at its beginning and its end.

### 5. `situational.after-eating`

- [ ] Arabic, translation, source, and count are all correct.

> الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَٰذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلَا قُوَّةٍ

**Transliteration.** Al-ḥamdu li'llāhi'lladhī aṭʿamanī hādhā wa razaqanīhi min ghayri ḥawlin minnī wa lā quwwah.

**Translation.** All praise is for Allah, who fed me this and provided it for me without any power or strength on my part.

**Source.** Abū Dāwūd; al-Tirmidhī — Abū Dāwūd 4023; al-Tirmidhī 3458  **⚠ verify reference**

**Count.** once

**Occasion.** After eating.

### 6. `situational.travel`

- [ ] Arabic, translation, source, and count are all correct.

> سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَٰذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ، وَإِنَّا إِلَىٰ رَبِّنَا لَمُنْقَلِبُونَ. اللَّهُمَّ إِنَّا نَسْأَلُكَ فِي سَفَرِنَا هَٰذَا الْبِرَّ وَالتَّقْوَىٰ، وَمِنَ الْعَمَلِ مَا تَرْضَىٰ، اللَّهُمَّ هَوِّنْ عَلَيْنَا سَفَرَنَا هَٰذَا وَاطْوِ عَنَّا بُعْدَهُ، اللَّهُمَّ أَنْتَ الصَّاحِبُ فِي السَّفَرِ، وَالْخَلِيفَةُ فِي الْأَهْلِ

**Transliteration.** Subḥāna'lladhī sakhkhara lanā hādhā wa mā kunnā lahu muqrinīn, wa innā ilā Rabbinā la-munqalibūn. Allāhumma innā nas'aluka fī safarinā hādha'l-birra wa't-taqwā, wa mina'l-ʿamali mā tarḍā. Allāhumma hawwin ʿalaynā safaranā hādhā wa'ṭwi ʿannā buʿdah. Allāhumma anta'ṣ-Ṣāḥibu fi's-safar, wa'l-Khalīfatu fi'l-ahl.

**Translation.** Glory is to the One who has subjected this to us, and we could never have done it by ourselves; and indeed to our Lord we will return. O Allah, we ask You on this journey of ours for righteousness and piety, and for deeds that please You. O Allah, make this journey easy for us and fold up its distance for us. O Allah, You are the Companion on the journey and the Guardian of the family left behind.

**Source.** Muslim — 1342

**Count.** once

**Occasion.** On setting out to travel.

### 7. `situational.entering-masjid`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ

**Transliteration.** Allāhumma'ftaḥ lī abwāba raḥmatik.

**Translation.** O Allah, open for me the doors of Your mercy.

**Source.** Muslim — 713

**Count.** once

**Occasion.** On entering the masjid.

### 8. `situational.leaving-masjid`

- [ ] Arabic, translation, source, and count are all correct.

> اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ

**Transliteration.** Allāhumma innī as'aluka min faḍlik.

**Translation.** O Allah, I ask You of Your bounty.

**Source.** Muslim — 713

**Count.** once

**Occasion.** On leaving the masjid.


---

## Reviewer sign-off

- Reviewer: ______________________________________________
- Date: __________________________________________________
- Qualifications / institution: ___________________________
- Notes, corrections, or items to remove:

  ```
  (space for corrections — please mark the item id)
  ```

- [ ] I have read every item above and the content file may be
      marked `reviewed`.

Once signed, set `"reviewStatus": "reviewed"` in
`Packages/IhsanCore/Sources/IhsanCore/Resources/adhkar-content.json`
and bump `contentVersion`.
