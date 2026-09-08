<#
    Build-CourseRecord.ps1 - generate assets/courses/*.json from the parsed
    Training and Assessment Strategies.

    THE TAS IS THE AUTHORITY FOR WHAT AN RTO DELIVERS, and training.gov.au is
    the authority for what a unit CONTAINS. This script joins the two: the unit
    list, designations, clusters and delivery status come from the TAS; titles,
    prerequisites and currency come from the harvested unit cache and OVERRIDE
    the TAS wherever they disagree, because a TAS is typed by hand and the
    national register is not. Every override is recorded in titleCorrections so
    the divergence stays visible rather than being silently healed.

    ONE RECORD PER INSTITUTE PER QUALIFICATION, NOT ONE PER QUALIFICATION.
    Three qualifications are delivered by two institutes, and when both TAS
    documents finally arrived they turned out to disagree: ACI and Meridian
    pick DIFFERENT ELECTIVES for SIT40521 and SIT50422. A single shared record
    would have to pick one and be wrong for the other, and since the elective
    set decides which unit owns a shared topic, it would be wrong in the one
    place that matters. Each institute gets its own record and its own topic
    map; `siblingCourse` points at the counterpart.

    THE DELIVERED SET IS NOT THE UNIT LIST. Several courses package 28-33 units
    and TEACH five to ten of them; the rest arrive by credit transfer from the
    course below on the pathway. Topic allocation runs over the DELIVERED set,
    and the credit-transferred units are the assumed prior knowledge.
#>
[CmdletBinding()]
param(
    [string] $UnitTsv,
    [string] $UnitCache,
    [string] $OutDir
)

$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $UnitCache) { $UnitCache = Join-Path $root '../assets/units' }
if (-not $OutDir)    { $OutDir    = Join-Path $root '../assets/courses' }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$DL = 'C:\Users\ACI-Admin\Downloads\'

# Unit codes an RTO typed wrong, and what the national register says they are.
# Corrected on the way in and recorded on the record.
$codeFix = @{
    'SITXFIN0010' = 'SITXFIN010'
    'BSBHRM6153'  = 'BSBHRM613'
}

# The counterpart record where two institutes deliver the same qualification.
$siblings = @{
    'ACI-SIT30821' = 'MVC-SIT30821'; 'MVC-SIT30821' = 'ACI-SIT30821'
    'ACI-SIT40521' = 'MVC-SIT40521'; 'MVC-SIT40521' = 'ACI-SIT40521'
    'ACI-SIT50422' = 'MVC-SIT50422'; 'MVC-SIT50422' = 'ACI-SIT50422'
}

# ---------------------------------------------------------------------------
# COURSE METADATA. One block per institute-course. Anything read from a
# document names that document; anything decided names the decision.
# ---------------------------------------------------------------------------
$courses = @(
  @{
    id='ACI-CPC20220'; provider='ACI'; variant='construction'; code='CPC20220'
    title='Certificate II in Construction Pathways'; aqf='Certificate II'; weeks=26
    tas=($DL + 'TAS CPC20220 Certificate II in Construction Pathways.docx')
    tasKey='A-CPC20220'
    packaging=@{ totalUnits=10; statedInTas=$true; rule='TAS states 10 units of competency.' }
    seqModel='cluster'
    clusters=@(
      @{ n=1; name='Industry Induction & WHS';     focus='White card, legal WHS requirements, sustainable work practices'; units=@('CPCWHS1001','CPCCWHS2001','CPCCOM1012') }
      @{ n=2; name='Work Planning & Measurements'; focus='Basic work planning, organising tasks, measuring and calculating'; units=@('CPCCOM1013','CPCCOM1015') }
      @{ n=3; name='Practical Tools & Site Safety';focus='Using hand tools and equipment for plastering, working safely at heights'; units=@('CPCCCM2012','CPCCSP2002') }
      @{ n=4; name='Trade Skills Application';     focus='Prepare surfaces for plastering, carry out basic concreting, complete a basic construction project'; units=@('CPCCSP2003','CPCCCO2013','CPCCVE1011') }
    )
    notes=@('Delivered over four terms, one cluster per term, with a term break between each.')
    openItems=@('CPC20220 nationally packages 12 units (6 core + 6 elective). This TAS states and lists 10. Confirm against the RTO scope of registration before the next intake.')
  },
  @{
    id='ACI-CPC31020'; provider='ACI'; variant='construction'; code='CPC31020'
    title='Certificate III in Solid Plastering'; aqf='Certificate III'; weeks=52
    tas=($DL + 'TAS CPC31020 Certificate III in Solid Plastering (2).docx')
    tasKey='A-CPC31020'
    packaging=@{ totalUnits=20; statedInTas=$true; rule='TAS states 20 units of competency.' }
    seqModel='cluster'
    clusters=@(
      @{ n=1; name='Core Industry Induction & WHS'; focus='White card, working effectively, sustainability, safety awareness'; units=@('CPCWHS1001','CPCCOM1012','CPCCWHS2001') }
      @{ n=2; name='Work Planning & Communication'; focus='Planning tasks, workplace communication, reading plans, measurements'; units=@('CPCCOM1013','CPCCOM1014','CPCCOM2001','CPCCOM1015') }
      @{ n=3; name='Site Setup & Access';           focus='Levelling, scaffold erection, working at heights'; units=@('CPCCCM2006','CPCCCM2008','CPCCCM2012') }
      @{ n=4; name='Materials & Tools Competency';  focus='Handling plastering materials, using tools'; units=@('CPCCSP2001','CPCCSP2002') }
      @{ n=5; name='Solid Plastering Applications'; focus='Preparing surfaces, float and render, set coats, texture finishes'; units=@('CPCCSP2003','CPCCSP3001','CPCCSP3002','CPCCSP3003') }
      @{ n=6; name='Restoration & Renovation Skills'; focus='Restoring damaged plasterwork'; units=@('CPCCSP3004') }
      @{ n=7; name='Related Trade Skills';          focus='Basic concreting for site preparation'; units=@('CPCCCO2013') }
      @{ n=8; name='Small Business Skills';         focus='Business opportunity investigation, managing finances'; units=@('BSBESB301','BSBESB407') }
    )
    notes=@('The TAS states WHS is not isolated to Cluster 1 - every cluster reapplies safe work practice during practical tasks. That is reinforcement of an OWNED topic, not re-teaching, and the topic register records it as applied-not-taught.')
    openItems=@()
  },
  @{
    id='ACI-CPC40120'; provider='ACI'; variant='construction'; code='CPC40120'
    title='Certificate IV in Building and Construction'; aqf='Certificate IV'; weeks=52
    tas=($DL + 'TAS CPC40120 Certificate IV in Building and Construction (Building) (1).docx')
    tasKey='A-CPC40120'
    packaging=@{ totalUnits=19; statedInTas=$true; rule='TAS states 19 units of competency.' }
    seqModel='timetable'
    seqSource=($DL + '1.8 Draft Timetable - CPC40120 Certificate IV in Building and Construction - Building.pdf')
    clusters=@()
    deliveryOrder=@(
      @{ code='CPCCBC4002'; weeks='1-2'   }
      @{ code='CPCCBC4001'; weeks='3-4'   }
      @{ code='CPCCBC4053'; weeks='5-6'   }
      @{ code='CPCCBC4009'; weeks='7-8'   }
      @{ code='CPCCBC4007'; weeks='9-10'  }
      @{ code='CPCCBC4012'; weeks='15-16' }
      @{ code='CPCCBC4014'; weeks='17-18' }
      @{ code='CPCCBC4004'; weeks='19-21' }
      @{ code='CPCCBC4005'; weeks='22-23' }
      @{ code='CPCCBC4006'; weeks='24-25' }
      @{ code='CPCCBC4003'; weeks='26-27' }
      @{ code='CPCCBC4024'; weeks='30-32' }
      @{ code='CPCCBC4008'; weeks='33-34' }
      @{ code='CPCCBC4021'; weeks='35-36' }
      @{ code='CPCCBC4010'; weeks='37-40' }
      @{ code='CPCCBC4018'; weeks='41-42' }
      @{ code='CPCSUS4002'; weeks='43-45' }
      @{ code='BSBESB401';  weeks='48-50' }
      @{ code='BSBPMG422';  weeks='51-52' }
    )
    notes=@('THE DELIVERY SEQUENCE COMES FROM THE DRAFT TIMETABLE, NOT THE TAS. The TAS clustering section is unusable - see openItems - but the draft timetable submitted alongside it in the same scope-application pack carries a correct week-by-week schedule of exactly these 19 units. That is the sequence recorded here, and it is what topic ownership is ordered by.')
    openItems=@(
      'THE TAS CARRIES THE WRONG DELIVERY PLAN, AND THE SEPTEMBER 2026 DOCX STILL DOES. Its Course Clustering Overview and Delivery Sequence sections were copied from the CPC20220 Certificate II strategy: they cluster and timetable CPCWHS1001, CPCCOM1012, CPCCOM1013, CPCCOM1015, CPCCCM2012, CPCCSP2002, CPCCSP2003, CPCCCO2013 and CPCCVE1011 - NINE units this qualification does not contain - plus one Diploma unit, CPCCBC5010. The registry sequences the course from the draft timetable instead, so builds are unblocked, but AN AUDITOR READING THE TAS FINDS A DELIVERY PLAN FOR A DIFFERENT QUALIFICATION. Rewrite that section.',
      'BSBESB401 Research and Develop Business Plans is listed in the unit table with no Core/Elective designation. Recorded as elective on the arithmetic - 14 core are designated and the TAS states 19 units - but confirm.'
    )
  },
  @{
    id='ACI-CPC50220'; provider='ACI'; variant='construction'; code='CPC50220'
    title='Diploma of Building and Construction (Building)'; aqf='Diploma'; weeks=104
    tas=($DL + 'TAS CPC50220 Diploma of Building and Construction - Building (1).docx')
    tasKey='A-CPC50220'
    packaging=@{ totalUnits=27; core=24; elective=3; statedInTas=$true; rule='TAS states 27 units - 24 core units plus 3 electives.' }
    seqModel='cluster'
    clusters=@(
      @{ n=1;  name='WHS & Risk Management';                   focus='Workplace health, safety, and business risk mitigation'; units=@('BSBWHS513','BSBOPS504') }
      @{ n=2;  name='Legal and Contractual Compliance';        focus='Legal frameworks and contract management'; units=@('CPCCBC4003','CPCCBC4009','CPCCBC5007') }
      @{ n=3;  name='Building Codes & Compliance';             focus='Application of building codes across building types'; units=@('CPCCBC4001','CPCCBC4053','CPCCBC5001') }
      @{ n=4;  name='Estimating and Procurement';              focus='Cost estimation, tendering, and procurement'; units=@('CPCCBC4004','CPCCBC4005','CPCCBC4013','CPCCBC5002') }
      @{ n=5;  name='Construction Site Operations';            focus='Site supervision and contractor management'; units=@('CPCCBC4008','CPCCBC5003','CPCCBC5005','CPCCBC5010') }
      @{ n=6;  name='Structural and Technical Design';         focus='Structural principles, plans, and technical reporting'; units=@('CPCCBC4010','CPCCBC5018','CPCCBC4012','CPCCBC4014','CPCCBC5013') }
      @{ n=7;  name='Surveying and Setout';                    focus='Site survey and set-out practices'; units=@('CPCCBC4018') }
      @{ n=8;  name='Environmental and Sustainable Practices'; focus='Sustainable and environmental responsibilities'; units=@('CPCCBC5011','CPCSUS5001') }
      @{ n=9;  name='Quality and Stakeholder Engagement';      focus='Quality systems and project communication'; units=@('BSBPMG532','BSBPMG538') }
      @{ n=10; name='Financial and Business Management';       focus='Financial control and business management'; units=@('CPCCBC5019') }
    )
    notes=@('Cluster 3 is marked in the TAS as carrying the prerequisite units for the codes clusters, and is sequenced before them.')
    openItems=@()
  },
  @{
    id='ACI-MSF30322'; provider='ACI'; variant='construction'; code='MSF30322'
    title='Certificate III in Cabinet Making and Timber Technology'; aqf='Certificate III'; weeks=92
    tas=($DL + '1.13 TAS MSF30322 Certificate III in Cabinet Making and timber technology.pdf')
    tasKey='MSF30322-ACI'
    packaging=@{ totalUnits=25; core=8; elective=17; statedInTas=$false; rule='25 units listed - 8 core plus 17 electives.' }
    seqModel='cluster'
    clusters=@(
      @{ n=1; name='WHS & Workplace Fundamentals';               focus='Induction and core workplace skills'; units=@('CPCWHS1001','CPCCWHS2001','MSMENV272','MSMSUP102','MSMSUP106') }
      @{ n=2; name='Measurement, Calculation and Documentation'; focus='Technical numeracy and job interpretation'; units=@('MSFGN2001','MSFGN3005','MSFFM3031','MSFFDM4002','MSFGN3006') }
      @{ n=3; name='Tools, Machines & Joints';                   focus='Basic and advanced tool usage'; units=@('MSFFM2013','MSFFM2016','MSFFM2017','MSFFM2018') }
      @{ n=4; name='Timber & Materials Selection';               focus='Material knowledge'; units=@('MSFFM3029','MSFFF2012') }
      @{ n=5; name='Drawing and CAD Skills';                     focus='Design and visual communication'; units=@('MSFFM3030','MSFFDM4012') }
      @{ n=6; name='Cabinetry Fabrication';                      focus='Construction of furniture and cabinetry'; units=@('MSFFM3042','MSFKB2003','MSFFM3041') }
      @{ n=7; name='Installation and On-Site Work';              focus='Installation and site organisation'; units=@('MSFFM3043','MSFKB3012','MSMOPS363') }
      @{ n=8; name='Customer Service and Delivery';              focus='Client engagement and job handover'; units=@('BSBOPS304') }
    )
    notes=@('An Adelaide Construction Institute course whose units carry MSF, MSM, CPC and BSB prefixes. NO UPDATED STRATEGY WAS SUPPLIED in the September 2026 batch, so this record still reads the 2025 PDF.')
    openItems=@(
      'BLOCKING FOR ANY BUILD - MSFGN2001 Make measurements and calculations is SUPERSEDED on training.gov.au. It sits in Cluster 2 as a core unit. Transition to the superseding unit before building or delivering against it.',
      'The assessment skill Resolve-BrandVariant maps CPC to the construction variant and throws on an unmapped package. MSF and MSM are unmapped, so an MSF unit cannot resolve a trading name. assets/providers.json records MSF and MSM as construction; the assessment skill needs the same mapping.'
    )
  },
  @{
    id='ACI-SIT20421'; provider='ACI'; variant='culinary'; code='SIT20421'
    title='Certificate II in Cookery'; aqf='Certificate II'; weeks=24
    tas=($DL + 'TAS SIT20421 Certificate II in Cookery.docx')
    tasKey='A-SIT20421'
    packaging=@{ totalUnits=13; core=7; elective=6; statedInTas=$true; rule='13 units - 7 core plus 6 electives; 4 from Group A, B or C and 2 from Group A, B, C or D.' }
    seqModel='sequence'
    clusters=@()
    notes=@('24 weeks: 20 weeks face to face, 2 weeks term break, and 12 service periods of work placement. The unit table is numbered and that numbering is the delivery order.')
    openItems=@()
  },
  @{
    id='ACI-SIT30821'; provider='ACI'; variant='culinary'; code='SIT30821'
    title='Certificate III in Commercial Cookery'; aqf='Certificate III'; weeks=52
    tas=($DL + 'TAS SIT30821 Certificate III in Commercial Cookery (1).docx')
    tasKey='A-SIT30821'
    packaging=@{ totalUnits=25; core=20; elective=5; statedInTas=$true; rule='25 units - 20 core plus 5 electives.' }
    seqModel='sequence'
    clusters=@()
    notes=@(
      '52 weeks: 48 weeks face to face, 4 weeks term break, and 48 service periods of work placement.',
      'ACI AND MERIDIAN SELECT THE IDENTICAL 25 UNITS for this qualification - confirmed by comparing the two strategies, not assumed. The two records still differ because the DELIVERY ORDER differs: Meridian groups its units into four themes, ACI lists a straight sequence.'
    )
    openItems=@('IS THE NUMBERING A TEACHING ORDER OR A LISTING ORDER? The ACI strategy numbers its 25 units 1 to 25 with no grouping. Meridian delivers the identical 25 in the identical order but groups them into four themes, and within a theme the units are taught as a block rather than strictly one after another. Three rulings turn on the difference: this register owns equipment in SITHCCC023, cleaning chemicals in SITHKOP009 and dietary requirements in SITHCCC042, and each of those units is numbered AFTER a unit that applies the topic. Under Meridian theme grouping they are simultaneous and the rulings hold; read as a strict sequence they should flip. Confirm which the numbering means, then either group the units into blocks in the strategy or re-rule those three topics here.')
  },
  @{
    id='ACI-SIT40521'; provider='ACI'; variant='culinary'; code='SIT40521'
    title='Certificate IV in Kitchen Management'; aqf='Certificate IV'; weeks=30
    tas=($DL + 'Training-and-Assessment-Strategy SIT40521 Certificate IV in Kitchen Management.docx')
    tasKey='A-SIT40521'
    packaging=@{ totalUnits=33; core=27; elective=6; statedInTas=$true; rule='33 units - 27 core plus 6 electives.' }
    seqModel='sequence'
    delivered=@('SITXHRM008','SITXHRM009','SITXCOM010','SITXWHS007','SITXFIN009','SITXMGT004','SITXFSA008','SITHKOP012','SITHKOP013','SITHKOP015')
    priorCourse='ACI-SIT30821'
    clusters=@()
    notes=@(
      'TEN OF THE THIRTY-THREE UNITS ARE DELIVERED. The other 23 arrive by credit transfer from SIT30821, which the TAS states learners hold on entry along with 48 completed service periods.',
      'ACI AND MERIDIAN DISAGREE ON THE ELECTIVES HERE. ACI carries SITHCCC025, SITHKOP012 and SITXHRM007; Meridian carries BSBTWK501 and SITXINV007 instead. That is why the two institutes hold separate records - a different elective set changes which unit owns a shared topic.'
    )
    openItems=@()
  },
  @{
    id='ACI-SIT50422'; provider='ACI'; variant='culinary'; code='SIT50422'
    title='Diploma of Hospitality Management'; aqf='Diploma'; weeks=30
    tas=($DL + 'Training-and-Assessment-Strategy SIT50422 Diploma of hospitality.docx')
    tasKey='A-SIT50422'
    packaging=@{ totalUnits=28; core=11; elective=17; statedInTas=$true; rule='28 units - 11 core plus 17 electives.' }
    seqModel='sequence'
    delivered=@('SITXGLC002','SITXFIN010','SITXCCS016','SITXMGT005','SITXCCS015')
    priorCourse='ACI-SIT40521'
    clusters=@()
    notes=@(
      'FIVE OF THE TWENTY-EIGHT UNITS ARE DELIVERED, on an advanced-standing pathway. The other 23 arrive by credit transfer.',
      'The five delivered units are the same five Meridian delivers, but IN A DIFFERENT ORDER - ACI opens with SITXGLC002, Meridian with SITXFIN010 - and the 28-unit sets differ: ACI carries SITHCCC025, SITHCCC031, SITHCCC032, SITHCCC038 and SITHCCC044 where Meridian carries BSBTWK501, SITHKOP013, SITHPAT016, SITXFSA006 and SITXINV006.'
    )
    openItems=@('The TAS names the credit-transfer source as SIT40516 Certificate IV in Commercial Cookery. That qualification code is SUPERSEDED - the current code is SIT40521 Certificate IV in Kitchen Management, which is what ACI actually delivers. Correct the reference.')
  },
  @{
    id='ACI-SITSS00069'; provider='ACI'; variant='culinary'; code='SITSS00069'
    title='Food Safety Supervision Skill Set'; aqf='Skill Set'; weeks=4
    tas=($DL + 'TAS Skill Set SITSS00069 Food Safety Supervision.docx')
    tasKey='A-SITSS00069'
    packaging=@{ totalUnits=2; statedInTas=$true; rule='Skill set - 2 units.' }
    seqModel='sequence'
    clusters=@()
    notes=@('A SKILL SET, NOT A QUALIFICATION. Four weeks, four weekly face-to-face classes with online study between them. It issues a Statement of Attainment, not a qualification, and it is not on the course prospectus alongside the AQF qualifications.')
    openItems=@('Neither unit carries a Core or Elective designation in the TAS table, because a skill set has no packaging rule of that kind. Both are recorded as Core.')
  },
  @{
    id='MVC-SIT30821'; provider='MVC'; variant=$null; code='SIT30821'
    title='Certificate III in Commercial Cookery'; aqf='Certificate III'; weeks=52
    tas=($DL + 'TAS SIT30821 Certificate III in Commercial Cookery (2).docx')
    tasKey='B-SIT30821'
    packaging=@{ totalUnits=25; core=20; elective=5; statedInTas=$true; rule='25 units - 20 core plus 5 electives; 3 from Group A or B and 2 from Group A, B or C.' }
    seqModel='theme'
    clusters=@(
      @{ n=1; name='WHS and workplace effectiveness'; weeks='1-6';   hours=72;  units=@('SITXWHS005','SITXWHS006','SITXHRM007') }
      @{ n=2; name='Kitchen operations, hygiene and stock'; weeks='7-16'; hours=171; units=@('SITHKOP010','SITXINV007','SITXFSA005','SITXFSA006','SITHKOP009','SITXINV006','SITHCCC023') }
      @{ n=3; name='Core cookery methods'; weeks='17-32'; hours=395; units=@('SITHCCC027','SITHPAT016','SITHCCC042','SITHCCC038','SITHCCC031','SITHCCC028','SITHCCC029','SITHCCC030') }
      @{ n=4; name='Specialised cookery and work placement'; weeks='33-48'; hours=412; units=@('SITHCCC032','SITHCCC035','SITHCCC036','SITHCCC037','SITHCCC041','SITHCCC044','SITHCCC043') }
    )
    notes=@(
      'THE THEMES ARE A GROUPING OF THE CURRENT DELIVERY ORDER, NOT A DIFFERENT ONE. The September 2026 strategy presents the units as a flat numbered sequence with no theme names; the earlier version grouped that SAME sequence into four themes, and the two orders are byte-identical across all 25 units. The themes are kept because they carry teaching information the flat list does not, and every topic ruling cites them.',
      'The strategy names the duplication problem this registry solves: recurring knowledge - WHS, hygiene, temperature control, mise en place, cleaning, storage, workflow - is consolidated progressively rather than retaught.'
    )
    openItems=@()
  },
  @{
    id='MVC-SIT31021'; provider='MVC'; variant=$null; code='SIT31021'
    title='Certificate III in Patisserie'; aqf='Certificate III'; weeks=58
    tas=($DL + 'TAS SIT31021 Certificte III in Patisserie (1).docx')
    tasKey='B-SIT31021'
    packaging=@{ totalUnits=21; core=15; elective=6; statedInTas=$true; rule='21 units - 15 core plus 6 electives.' }
    seqModel='theme'
    clusters=@(
      @{ n=1; name='Work safely and hygienically (foundation)'; units=@('SITXWHS005','SITXFSA005','SITXFSA006','SITXWHS006') }
      @{ n=2; name='Kitchen operations and stock'; units=@('SITHKOP010','SITXINV007','SITXINV006','SITHKOP009','SITHCCC023') }
      @{ n=3; name='Core cookery and people skills'; units=@('SITHCCC027','SITXHRM007','SITHCCC042','SITHCCC038') }
      @{ n=4; name='Patisserie production'; units=@('SITHPAT016','SITHPAT011','SITHPAT012','SITHPAT013','SITHPAT014','SITHPAT015','SITHPAT017') }
      @{ n=5; name='Apply skills in the commercial kitchen (service periods)'; units=@('SITHCCC034') }
    )
    notes=@('58 weeks including 6 weeks term break. As with SIT30821, the September 2026 strategy presents a flat numbered sequence and the themes recorded here group that same order.')
    openItems=@()
  },
  @{
    id='MVC-SIT40521'; provider='MVC'; variant=$null; code='SIT40521'
    title='Certificate IV in Kitchen Management'; aqf='Certificate IV'; weeks=30
    tas=($DL + 'TAS SIT40521 Certificate IV Kitchen Management.docx')
    tasKey='B-SIT40521'
    packaging=@{ totalUnits=33; core=27; elective=6; statedInTas=$true; rule='TAS states 33 units - 27 core plus 6 electives.' }
    seqModel='sequence'
    delivered=@('BSBTWK501','SITXHRM009','SITXCOM010','SITXWHS007','SITXFIN009','SITXMGT004','SITXHRM008','SITXFSA008','SITHKOP013','SITHKOP015')
    priorCourse='MVC-SIT30821'
    clusters=@()
    notes=@(
      'TEN OF THE UNITS ARE DELIVERED, on advanced standing; the rest arrive by credit transfer from SIT30821.',
      'MERIDIAN AND ACI DISAGREE ON THE ELECTIVES. Meridian carries BSBTWK501 and SITXINV007; ACI carries SITHCCC025, SITHKOP012 and SITXHRM007 instead. Meridian also DELIVERS BSBTWK501, which does not appear in ACI list at all.'
    )
    openItems=@('The TAS states 33 units but its core-and-elective table lists 32. One unit is missing from the table. Reconcile before the next intake.')
  },
  @{
    id='MVC-SIT50422'; provider='MVC'; variant=$null; code='SIT50422'
    title='Diploma of Hospitality Management'; aqf='Diploma'; weeks=30
    tas=($DL + 'TAS SIT50422 Diploma of Hospitality Management.docx')
    tasKey='B-SIT50422'
    packaging=@{ totalUnits=28; core=11; elective=17; statedInTas=$true; rule='28 units - 11 core plus 17 electives.' }
    seqModel='sequence'
    delivered=@('SITXFIN010','SITXCCS016','SITXGLC002','SITXMGT005','SITXCCS015')
    priorCourse='MVC-SIT40521'
    clusters=@()
    notes=@(
      'FIVE OF THE TWENTY-EIGHT UNITS ARE DELIVERED. The strategy is written for learners on the pathway Certificate III Commercial Cookery to Certificate IV Kitchen Management to this Diploma; the other 23 arrive by credit transfer.',
      'ACI delivers the same five units in a different order, and its 28-unit set differs: ACI carries SITHCCC025, SITHCCC031, SITHCCC032, SITHCCC038 and SITHCCC044 where Meridian carries BSBTWK501, SITHKOP013, SITHPAT016, SITXFSA006 and SITXINV006.'
    )
    openItems=@('The TAS unit table types SITXFIN010 as SITXFIN0010. Corrected against training.gov.au and recorded in titleCorrections.')
  },
  @{
    id='MVC-SIT60322'; provider='MVC'; variant=$null; code='SIT60322'
    title='Advanced Diploma of Hospitality Management'; aqf='Advanced Diploma'; weeks=30
    tas=($DL + 'TAS SIT60322 Advanced Diploma of Hospitality Management.docx')
    tasKey='B-SIT60322'
    packaging=@{ totalUnits=33; core=14; elective=19; statedInTas=$true; rule='33 units - 14 core plus 19 electives.' }
    seqModel='sequence'
    delivered=@('BSBOPS601','BSBFIN601','SITXFIN011','SITXHRM010','SITXHRM012','SITXMPR014','SITXWHS008')
    priorCourse='MVC-SIT50422'
    clusters=@()
    notes=@('SEVEN OF THE THIRTY-THREE UNITS ARE DELIVERED. Credit transfer applies from SIT30821, SIT40521 and SIT50422 - the full pathway below this qualification.')
    openItems=@()
  },
  @{
    id='MVC-BSB50420'; provider='MVC'; variant=$null; code='BSB50420'
    title='Diploma of Leadership and Management'; aqf='Diploma'; weeks=52
    tas=($DL + 'TAS BSB50420 Diploma of Leadership and Management.docx')
    tasKey='B-BSB50420'
    packaging=@{ totalUnits=12; core=6; elective=6; statedInTas=$true; rule='12 units - 6 core plus 6 electives; 4 from the listed electives and up to 2 from elsewhere.' }
    seqModel='sequence'
    clusters=@()
    notes=@('52 weeks including 4 weeks term break. All 12 units are delivered - there is no credit-transfer pathway into this qualification. The unit table is numbered and that numbering is the delivery order.')
    openItems=@()
  },
  @{
    id='MVC-BSB60420'; provider='MVC'; variant=$null; code='BSB60420'
    title='Advanced Diploma of Leadership and Management'; aqf='Advanced Diploma'; weeks=52
    tas=($DL + 'TAS BSB60420 - Advanced Diploma of Leadership and Management.docx')
    tasKey='B-BSB60420'
    packaging=@{ totalUnits=10; core=5; elective=5; statedInTas=$true; rule='10 units - 5 core plus 5 electives; 3 from the listed electives and up to 2 from elsewhere.' }
    seqModel='sequence'
    clusters=@()
    notes=@('52 weeks including 4 weeks term break. All 10 units delivered.')
    openItems=@()
  },
  @{
    id='MVC-BSB80120'; provider='MVC'; variant=$null; code='BSB80120'
    title='Graduate Diploma of Management (Learning)'; aqf='Graduate Diploma'; weeks=52
    tas=($DL + 'TAS BSB80120 Graduate Diploma of Management (Learning).docx')
    tasKey='B-BSB80120'
    packaging=@{ totalUnits=8; core=3; elective=5; statedInTas=$true; rule='8 units - 3 core plus 5 electives; 3 from the listed electives and up to 2 from elsewhere.' }
    seqModel='sequence'
    clusters=@()
    notes=@('52 weeks including 4 weeks term break. All 8 units delivered.')
    openItems=@('The TAS types BSBHRM613 Contribute to the development of learning and development strategies as BSBHRM6153 - one digit too many, and no such unit exists on training.gov.au. Corrected on the way in and recorded in titleCorrections. A student training plan for this qualification carries the same table and marks only two units as Core where the packaging rule requires three; check the designations against the rule.')
  }
)

# ---------------------------------------------------------------------------

$providers = (Get-Content -LiteralPath (Join-Path $root '../assets/providers.json') -Raw -Encoding UTF8 | ConvertFrom-Json).providers
function Get-Institute {
    param([string]$Provider, $Variant)
    $p = $providers.$Provider
    if ($Variant) { return $p.variants.$Variant.tradingName }
    return $p.tradingName
}

$tsv = Get-Content -LiteralPath $UnitTsv -Encoding UTF8
$byCourse = @{}
$cur = $null
foreach ($line in $tsv) {
    if ($line -match '^=====\s+(\S+)\s+=====') { $cur = $Matches[1]; $byCourse[$cur] = @(); continue }
    if ($null -eq $cur) { continue }
    $p = $line -split "`t"
    if ($p.Count -lt 4) { continue }
    $byCourse[$cur] += [pscustomobject]@{ Code = $p[1].Trim(); Designation = $p[2].Trim(); Title = $p[3].Trim() }
}

foreach ($c in $courses) {
    $rows = $byCourse[$c.tasKey]
    if (-not $rows) { Write-Warning "no parsed rows for $($c.tasKey)"; continue }

    $clusterOf = @{}
    foreach ($cl in $c.clusters) { foreach ($u in $cl.units) { $clusterOf[$u] = $cl.n } }

    $units = @(); $corrections = @(); $missing = @()
    $seq = 0
    foreach ($r in $rows) {
        $code = $r.Code
        if ($codeFix.ContainsKey($code)) {
            $corrections += [ordered]@{ code=$codeFix[$code]; what='unit code'; tas=$code; register=$codeFix[$code] }
            $code = $codeFix[$code]
        }
        $seq++
        $cacheFile = Join-Path $UnitCache "$code.json"
        if (-not (Test-Path $cacheFile)) { $missing += $code; continue }
        $u = Get-Content -LiteralPath $cacheFile -Raw -Encoding UTF8 | ConvertFrom-Json

        if ($r.Title -and $u.title -ne $r.Title) {
            $corrections += [ordered]@{ code=$code; what='unit title'; tas=$r.Title; register=$u.title }
        }
        $desig = if ($r.Designation) { (Get-Culture).TextInfo.ToTitleCase($r.Designation.ToLower()) } else { 'Core' }

        $status = 'delivered'
        if ($c.ContainsKey('delivered') -and $c.delivered) {
            $status = if ($c.delivered -contains $code) { 'delivered' } else { 'credit-transfer' }
        }

        $ordIx = $null; $ordWeeks = $null
        if ($c.ContainsKey('deliveryOrder')) {
            for ($k = 0; $k -lt $c.deliveryOrder.Count; $k++) {
                if ($c.deliveryOrder[$k].code -eq $code) { $ordIx = $k + 1; $ordWeeks = $c.deliveryOrder[$k].weeks; break }
            }
        }
        $sequence = if ($null -ne $ordIx) { $ordIx }
                    elseif ($c.seqModel -eq 'sequence' -and $c.ContainsKey('delivered')) {
                        $ix = [array]::IndexOf([string[]]$c.delivered, $code); if ($ix -ge 0) { $ix + 1 } else { $null }
                    } else { $seq }

        $units += [ordered]@{
            code            = $code
            title           = $u.title
            designation     = $desig
            deliveryStatus  = $status
            cluster         = $(if ($clusterOf.ContainsKey($code)) { $clusterOf[$code] } else { $null })
            sequence        = $sequence
            weeks           = $ordWeeks
            prerequisites   = @($u.prerequisites | ForEach-Object { $_.code })
            status          = $u.status
            statusLabel     = $u.statusLabel
            releaseCurrency = $u.currency
        }
    }

    $tasHash = if (Test-Path $c.tas) { (Get-FileHash -LiteralPath $c.tas -Algorithm SHA256).Hash } else { 'FILE-NOT-FOUND' }
    $deliveredCount = @($units | Where-Object { $_.deliveryStatus -eq 'delivered' }).Count
    $superseded     = @($units | Where-Object { $_.status -ne 'current' } | ForEach-Object { $_.code })
    $institute      = Get-Institute -Provider $c.provider -Variant $c.variant

    $rec = [ordered]@{
        schemaVersion      = '2.0'
        courseId           = $c.id
        qualificationCode  = $c.code
        qualificationTitle = $c.title
        productType        = $(if ($c.code -match '^\w{3}SS') { 'skill set' } else { 'qualification' })
        aqfLevel           = $c.aqf
        provider           = $c.provider
        brandVariant       = $c.variant
        institute          = $institute
        siblingCourse      = $(if ($siblings.ContainsKey($c.id)) { $siblings[$c.id] } else { $null })
        durationWeeks      = $c.weeks
        packagingRule      = $c.packaging
        unitCount          = $units.Count
        deliveredCount     = $deliveredCount
        priorCourse        = $(if ($c.ContainsKey('priorCourse')) { $c.priorCourse } else { $null })
        sequencing         = [ordered]@{
            model    = $c.seqModel
            source   = $(if ($c.ContainsKey('seqSource')) { $c.seqSource } else { $c.tas })
            clusters = @($c.clusters | ForEach-Object {
                [ordered]@{
                    number       = $_.n
                    name         = $_.name
                    focus        = $(if ($_.ContainsKey('focus')) { $_.focus } else { $null })
                    weeks        = $(if ($_.ContainsKey('weeks')) { $_.weeks } else { $null })
                    nominalHours = $(if ($_.ContainsKey('hours')) { $_.hours } else { $null })
                    units        = $_.units
                }
            })
            order    = @(if ($c.ContainsKey('deliveryOrder')) { $c.deliveryOrder | ForEach-Object { [ordered]@{ code=$_.code; weeks=$_.weeks } } })
        }
        units              = $units
        supersededUnits    = $superseded
        titleCorrections   = $corrections
        unitsNotInCache    = $missing
        source             = [ordered]@{
            tasFile      = $c.tas
            tasSha256    = $tasHash
            unitSource   = 'training.gov.au REST API, harvested to assets/units/'
            generatedUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        }
        notes              = $c.notes
        openItems          = $c.openItems
    }

    $dest = Join-Path $OutDir "$($c.id).json"
    [System.IO.File]::WriteAllText($dest, ($rec | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding $true))
    $flag = if ($superseded) { "  ** superseded: $($superseded -join ',') **" } else { '' }
    Write-Host ("  {0,-15} {1,-32} {2,2} units, {3,2} delivered, {4} corrections{5}" -f $c.id, $institute, $units.Count, $deliveredCount, $corrections.Count, $flag)
    if ($missing) { Write-Host ("     NOT IN CACHE: " + ($missing -join ', ')) -ForegroundColor Red }
}
