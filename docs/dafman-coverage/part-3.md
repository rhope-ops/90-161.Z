# Part 3: lines 2699-3719

Scope: Chapter 5 (staffing, coordination, certification and approval), Chapter 6 (delivering final publications), Chapter 7 (publication management, updates and rescissions) of ref/dafman90-161.txt. Abbreviations in "Covered by": process-model.md, DECISIONS.md, ARCHITECTURE.md, format-rules.md are in docs/; "list design" = docs/reviews/2026-11-12-list-design-full-scope.md; GC = docs/reviews/2026-11-12-dafman-full-gap-check.md; IR = docs/reviews/2026-11-12-independent-review.md; schema = schemas/lists/*.json; New-Publication.ps1 = scripts/gov/. Line numbers after a file name are lines in that file.

| Para | Line | Requirement (own words, max 25 words) | Tier | Actor | Applies to ANG wing | Covered by | Status |
|---|---|---|---|---|---|---|---|
| 5.1 | 2703 | Formal coordination and legal review finish before certifier and approver sign the DAF Form 673; the approved package then goes to AFIMPT (T-3). | T-3 | OPR | Partial: coordination order applies; AFIMPT submission does not (wing posts locally, 1.1.3.2) | process-model.md:14-19; list design:57 | Covered |
| 5.1 (365 days) | 2710 | If coordination is 365 days old or less with no significant draft change, the OPR states on the 673 that no re-coordination is needed. | T-1 | OPR | Yes | process-model.md:30; list design:58 | Covered |
| 5.1.1 | 2713 | DELETED | - | - | No (deleted) | - | Info |
| 5.1.2 | 2714 | DELETED | - | - | No (deleted) | - | Info |
| 5.1.3 | 2715 | PCMs with AOs decide who coordinates; use Table A3.1 mandatory and A3.2 recommended offices, plus any office with functional interest. | - | PCM | Yes | process-model.md:42,44; docs/coordination-table-a3-2.md; DECISIONS.md:22 (Q1), :11 (3B) | Covered |
| 5.1.4 | 2725 | OPRs send draft and prescribed forms to the required organizations per Table A3.1/A3.2; wing level means the local offices. | - | OPR | Yes (local offices) | process-model.md:14,44; docs/coordination-table-a3-2.md | Covered |
| 5.1.4 Note | 2727 | The AO ensures the unit privacy monitor reviews the publication before it is released for formal coordination. | - | AO | Yes | process-model.md:13; schema PFMEndorsements.CoordinationStage "Privacy Review" | Covered |
| 5.1.4.1 | 2729 | 2-Ltr/L2 offices get their organization to review and return one consolidated response, which a lower office may sign. | - | coordinator | Yes (wing offices) | schema PFMEndorsements.Endorser, CoordinationRole (one row per office) | Covered |
| 5.1.4.2 | 2738 | AO staffs to both Services unless the parent PD is Service-specific; opening paragraph states whether the Sister Service is included or excluded. | - | AO | Partial: opening-paragraph statement only (ANG wing is USAF) | format-rules F-025 (applicability statement) | Renderer |
| 5.1.4.3 (transcribe) | 2747 | Endorsements may be transcribed from e-mail or other tasks; endorsers may e-sign the 673 with //SIGNED// in the Coordinators column. | - | coordinator | Yes | process-model.md:55; list design:56 (master 673), :41 | Covered |
| 5.1.4.3 (15 days) | 2751 | Organizations get 15 business days to provide coordination. | T-3 | OPR | Yes | process-model.md:27; schema PFMSettings seed CoordinationSuspenseBusinessDays (PFMSettings.json:52); PFMPublications.CoordinationSuspense | Covered |
| 5.1.4.3 (extension) | 2752 | An office needing more time asks the OPR for an extension on or before the suspense date; otherwise the package proceeds. | - | coordinator | Yes | process-model.md:29; schema PFMEndorsements.ExtensionDate, ExtensionRationale | Covered |
| 5.1.5 | 2754 | Coordination may be collected by e-mail, approved systems or SSS; Section I and blocks 21a/22a of the 673 are filled before the tasker. | T-1 (final 673) | OPR | Yes | process-model.md:55; list design:56 | Covered |
| 5.1.5 (master 673) | 2757 | Returned endorsements are transcribed to a master DAF Form 673 before certification and approval. | - | OPR | Yes | process-model.md:55; list design:29 (Master DAF Form 673 Link) | Covered |
| 5.1.5 (package) | 2759 | The staffing package for formal and legal coordination holds the Word draft (text flush left), a CRM and a completed 673. | - | OPR | Yes | process-model.md:14; list design:28,56 (package gate) | Covered |
| 5.1.5 (consolidated 673) | 2761 | A consolidated 673 accompanies the final draft; the OPR does not release the final until all nonconcurs are resolved and coordination is full. | T-1 | OPR | Yes | process-model.md:18; list design:58 (nonconcur gate, PFM 1A) | Covered |
| 5.1.5 (originals) | 2763 | Original documents holding the endorsements stay in the publication record set; the transcription omits the signature. | - | OPR | Yes | DECISIONS.md:18 (Q15A); list design:50 (Record Sets folder). No rule that endorsement originals are filed | Partial |
| 5.1.6 | 2767 | Coordination of classified and CUI publications and forms follows the same standards; contact coordinating offices for routing. | - | OPR | Partial: CUI yes; classified excluded by PFM | list design:35 (Access Level); DECISIONS.md:42 (classified products left out) | Partial |
| 5.1.6 Note | 2770 | Do not send classified information over an unclassified network. | T-0 | all | Yes | AGENTS.md data boundary; DECISIONS.md:42. No gate or warning in the list design | Partial |
| 5.1.7 | 2773 | PMs and GMs skip full coordination; a wing GM needs local legal review. | T-1 | OPR | Yes (GM only; PM is HQ DAF) | process-model.md:21,66 | Covered |
| 5.1.7 (justification) | 2778 | OPR gives full justification on the 673 or staff package for issuing a PM or GM, explaining its time-sensitive nature. | T-1 | OPR | Yes (GM) | list design:39 (Guidance Memorandum Justification); process-model.md:66 | Covered |
| 5.1.8 | 2780 | Heading: Legal Review. | - | - | Yes | - | Info |
| 5.1.8.1 | 2784 | AF/JA gives formal coordination and mandatory legal review for HQ DAF-issued publications. | T-1 | HQ DAF | No (AF/JA, HQ DAF only) | - | N/A |
| 5.1.8.1 (final legal) | 2789 | Do not route for final legal review until all required coordination is done, documented on the 673, and comments are adjudicated. | - | OPR | Yes (applied to servicing legal office via 5.1.8.2) | process-model.md:15; DECISIONS.md:13 (1A); list design:57 | Covered |
| 5.1.8.1.1 | 2793 | AF/JA recommends SAF/GC review where needed; SAF/GC and AF/JA review HQDAFMDs, PDs and PMs. | - | HQ DAF | No (AF/JA, SAF/GC only) | - | N/A |
| 5.1.8.1.2 | 2797 | AF/JA gives final legal review after coordination and adjudication. | - | HQ DAF | No (AF/JA only) | - | N/A |
| 5.1.8.1.3 | 2799 | AF/JA formally coordinates all actions that change departmental publications. | - | HQ DAF | No (departmental only) | - | N/A |
| 5.1.8.1.4 | 2801 | Informal collaboration with AF/JA offices through the tasking system is encouraged. | - | HQ DAF | No (AF/JA only) | - | N/A |
| 5.1.8.2 | 2804 | For publications below HQ DAF, the servicing legal office provides formal coordination and mandatory legal review. | - | coordinator | Yes | process-model.md:15,42; schema PFMEndorsements.CoordinationRole Legal, CoordinationStage Legal | Covered |
| 5.2 | 2806 | OPRs set a reasonable suspense; coordinators get 15 business days. | T-3 | OPR | Yes | process-model.md:27; PFMSettings.json:52 | Covered |
| 5.2.1 | 2809 | Offices unable to meet suspense ask the OPR for an extension with rationale and estimated completion date; OPR allows reasonable time. | - | coordinator | Yes | process-model.md:29; schema PFMEndorsements.ExtensionDate, ExtensionRationale | Covered |
| 5.2.2 | 2814 | Guard and reserve applicability: 15 business days at MAJCOM and above; for publications below MAJCOM, give wings, units and subunits at least 30 calendar days. | - | OPR | Yes | process-model.md:28 (open: whether it covers wing-to-unit coordination); PFMSettings.json:57 | Partial |
| 5.3 | 2821 | OPRs give coordinators a CRM with nine named columns: item, source, comment type, page, paragraph, line, comment, rationale, decision. | T-1 | OPR | Yes | process-model.md:38; templates/CRM_A12-1.docx (build_crm_template.js:25,48); PFMEndorsements.CRMLink | Covered |
| 5.3 (POC) | 2827 | Each coordinator designates a POC for resolution; the POC may not be a contractor or indirect-hire foreign national. | - | coordinator | Yes | - (CRM template has no POC field; no check) | Gap |
| 5.3 Note | 2830 | Comment type must be administrative, substantive or critical; "Major" is not allowed. | T-1 | coordinator | Yes | templates/build_crm_template.js:25,39-40 (types A/S/C) | Covered |
| 5.3.1 | 2831 | Administrative comments address typographical, grammatical and formatting errors. | - | coordinator | Yes | templates/build_crm_template.js:39-40; process-model.md:38 | Info |
| 5.3.2 | 2832 | Substantive comments address unnecessary, incorrect, misleading, confusing or inconsistent content; coordinators nonconcurring on them alone state which comments are the basis. | - | coordinator | Yes | templates/build_crm_template.js:40 (text in CRM instructions) | Info |
| 5.3.3 | 2837 | A critical comment (legal sufficiency, law violation, safety, waste, undue burden) precludes approval and forces a nonconcur. | - | coordinator | Yes | process-model.md:38,56; list design:41 (Critical Comment); GC A21 | Covered |
| 5.4 | 2843 | Section II of the 673 gives each coordinator one best overall response for the whole publication. | - | coordinator | Yes | schema PFMEndorsements.EndorsementStatus; process-model.md:34 | Covered |
| 5.4.1 | 2846 | Concur: agrees with content and with the stated releasability. | - | coordinator | Yes | process-model.md:34 | Covered |
| 5.4.1 Note | 2849 | A coordinator may not concur if a critical comment has been made. | - | coordinator | Yes | list design:41 (Critical Comment forces Nonconcur); GC A21 | Covered |
| 5.4.2 | 2851 | Concur With Comment: agrees with content but gave administrative or substantive comments. | - | coordinator | Yes | process-model.md:34 | Covered |
| 5.4.2 Note | 2852 | A coordinator may not concur with comment if a critical comment has been made. | - | coordinator | Yes | list design:41 (Critical Comment) | Covered |
| 5.4.3 | 2854 | Concur-No Response: no extension request or response by suspense; not valid for legal review, and OPR cannot proceed without legal review. | T-3 | OPR | Yes | process-model.md:34; list design:57 (Legal never Concur-No Response) | Covered |
| 5.4.3.1 | 2858 | OPR makes a good-faith effort to learn why a coordinator did not respond, asking the PCM or SME for help. | - | OPR | Yes | process-model.md:34 (good-faith effort recorded on 673) | Covered |
| 5.4.3.2 | 2866 | OPR proceeds, marks Concur-No Response, and explains in the staff package why release without the response is appropriate. | T-3 | OPR | Yes | process-model.md:56; list design:41 (No Response Explanation) | Covered |
| 5.4.4 | 2870 | Nonconcur: critical and substantive comments are labeled and grouped; coordinators say which non-critical comments are the grounds. | T-1 | coordinator | Yes | process-model.md:34,38; templates/build_crm_template.js:40. No CRM column or field for "basis for nonconcur" | Partial |
| 5.4.5 | 2877 | No Comment: coordinator reviewed and has no equity interest. | - | coordinator | Yes | process-model.md:34 | Covered |
| 5.5 | 2880 | OPR owns comment resolution; resolution record goes in the record set; coordinators designate a non-contractor AO; copy of resolved comments may be shared. | T-1 | OPR | Yes | schema PFMEndorsements.NonconcurResolution, CRMLink; DECISIONS.md:18 (record sets). POC/AO contractor limit (see 5.3) not checked | Partial |
| 5.5.1 | 2889 | OPRs resolve all nonconcurs before final processing; critical and nonconcur-causing substantive comments must be resolved before approval. | - | OPR | Yes | DECISIONS.md:13 (1A); list design:58; process-model.md:17 | Covered |
| 5.5.2 | 2893 | Unresolved comments are elevated in the OPR chain (T-3); if still stuck, an impasse memo goes to the approver and joins the permanent record set. | T-3 | OPR | Yes | schema PFMEndorsements.NonconcurResolution (Elevated, Impasse Memo to Approving Official); list design:37 (Impasse Memo Link); DECISIONS.md:13 | Covered |
| 5.5.2 Note | 2896 | The OPR stays involved even if the matter is elevated. | T-1 | OPR | Yes | - (behavioral; no tracking needed) | Info |
| 5.5.2.1 | 2903 | Departmental-level publications. | - | - | No (departmental only) | - | N/A |
| 5.5.2.1.1 | 2904 | Same HQ DAF 2-Ltr/L2: approving official decides impasses. | - | approver | No (departmental only) | - | N/A |
| 5.5.2.1.2 | 2910 | Different 2-Ltr/L2: the certifier with PD oversight decides impasses. | - | certifier | No (departmental only) | - | N/A |
| 5.5.2.2 | 2913 | Command or field level: the approving official decides impasses. | - | approver | Yes | schema PFMEndorsements.NonconcurResolution "Impasse Memo to Approving Official"; process-model.md:17 | Covered |
| 5.5.2.2 Note | 2914 | For a supplement versus the guidance it supplements, the approving official of the higher-headquarters publication decides. | - | approver | Yes (supplements) | - | Gap |
| 5.5.3 | 2917 | A nonconcurrence is resolved by written withdrawal or by full acceptance of the comments. | - | OPR | Yes | schema PFMEndorsements.NonconcurResolution, ResolutionDate | Covered |
| 5.5.3.1 | 2918 | Withdrawal is written and endorsed at the same or higher level as the original coordination, or as delegated. | - | coordinator | Yes | schema PFMEndorsements.NonconcurResolution "Withdrawn" | Covered |
| 5.5.3.2 | 2921 | If comments are accepted in full, no withdrawal is needed, but the 673 gets a new entry for that office noting resolution. | - | OPR | Yes | schema PFMEndorsements.NonconcurResolution "Comments Incorporated". No prompt for the new 673 entry | Partial |
| 5.6 | 2925 | Heading: Certification. | - | - | Yes | - | Info |
| 5.6.1 | 2926 | After coordination, the OPR obtains the certifier's manual or digital signature on the 673; the digital signature may not be altered. | T-1 | OPR | Yes | DECISIONS.md:24 (Q4A signed PDF, flow records dates); process-model.md:16 | Covered |
| 5.6.2 | 2930 | Certification endorses the need, currency, DAF applicability and propriety of content, and consistency with higher policy. | - | certifier | Yes | process-model.md:16 | Info |
| 5.6.3 | 2937 | The certifying official is the lowest-level DAF official responsible for the publication's scope. | - | certifier | Yes | process-model.md:42 (OPR identifies its own certifier); schema PFMPublications.CertifyingOfficial | Covered |
| 5.6.3 Note | 2939 | The certifier of a PD approves implementing departmental guidance. | - | certifier | No (departmental only) | - | N/A |
| 5.6.3.1 | 2941 | Departmental-level publications and forms. | - | - | No (departmental only) | - | N/A |
| 5.6.3.1.1 | 2942 | Policy publications (PDs, PMs, DoDD supplements): certifier. | - | certifier | No (HQ DAF only) | - | N/A |
| 5.6.3.1.1.1 | 2943 | Certifier is the HQ DAF 2-Ltr/L2 owning the series. | - | certifier | No (HQ DAF only) | - | N/A |
| 5.6.3.1.1.2 | 2946 | Example of a PD certified by SAF/IG and approved by SecAF. | - | certifier | No (HQ DAF only) | - | N/A |
| 5.6.3.1.2 | 2954 | Guidance publications and forms (departmental): certifier. | - | certifier | No (HQ DAF only) | - | N/A |
| 5.6.3.1.2.1 | 2956 | Certifier is the HQ DAF 3-Ltr/L3 in the approver's organization. | - | certifier | No (HQ DAF only) | - | N/A |
| 5.6.3.1.2.2 | 2960 | If an outside organization's PD owns the guidance, that 2-Ltr/L2 certifies. | - | certifier | No (HQ DAF only) | - | N/A |
| 5.6.3.1.2.3 | 2965 | Example of a policy-oversight certifier. | - | certifier | No (HQ DAF only) | - | Info |
| 5.6.3.2 | 2973 | Command and field level publications and forms. | - | - | Yes | process-model.md:57 | Info |
| 5.6.3.2.1 | 2975 | Certifier is one level above the OPR and one level below the approving authority. | - | certifier | Yes | process-model.md:57; GC A8 | Covered |
| 5.6.3.2.2 | 2977 | If the official above the OPR is the approver, the OPR director may certify or the approver signs as both. | - | certifier | Yes | process-model.md:57 | Covered |
| 5.7 | 2980 | Heading: Approval. | - | - | Yes | - | Info |
| 5.7.1 | 2981 | After certification, the OPR obtains approval. | - | OPR | Yes | process-model.md:16-17 | Covered |
| 5.7.2 | 2982 | Approval releases the publication for compliance and attests currency and consistency with law, policy and mission. | - | approver | Yes | process-model.md:17 | Info |
| 5.7.3 | 2985 | If a lower-level publication is less restrictive than the higher one, coordinate with the servicing legal office on that issue before publication. | - | OPR | Yes | list design:31 (Less Restrictive Than HHQ); GC B16 (:59) | Covered |
| 5.7.4 | 2988 | If signing authority is delegated, the delegation letter is on file with the PFM or attached to the final package. | T-1 | OPR | Yes | process-model.md:17; schema PFMPublications.DelegationLetterLink (PFMPublications.json:209) | Covered |
| 5.7.5 | 2990 | The OPR obtains the approver's manual or digital signature on the 673; the digital signature may not be altered. | T-1 | OPR | Yes | DECISIONS.md:24 (Q4A); process-model.md:17 | Covered |
| 5.7.6 | 2993 | Heading: Identifying the Approving Official. | - | - | Yes | - | Info |
| 5.7.6.1 | 2997 | Departmental-level publications and forms. | - | - | No (departmental only) | - | N/A |
| 5.7.6.1.1 | 2998 | SecAF approves all departmental policy publications. | - | approver | No (SecAF only) | - | N/A |
| 5.7.6.1.2 | 3000 | HQ DAF 2-Ltr/L2 heads approve guidance publications and forms; delegation copy to AFDPO. | - | approver | No (HQ DAF only) | - | N/A |
| 5.7.6.2 | 3008 | MAJCOM/FLDCOM 2-Ltr/L2 heads approve MAJCOM/FLDCOM publications and forms. | - | approver | No (MAJCOM level) | - | N/A |
| 5.7.6.3 | 3013 | Below HQ DAF and MAJCOM, the commander or director responsible for the activity must approve (acting or deputy if absent). | T-1 | approver | Yes | process-model.md:42 (OPR identifies approver); schema PFMPublications.ApprovingOfficial. No check that the approver is a commander or director | Partial |
| 5.7.7 | 3018 | The approving official may also serve as the certifying official. | - | approver | Yes | process-model.md:57 | Covered |
| 6.1 | 3026 | Heading: posting unclassified publications and forms on e-Publishing. | - | - | No (e-Publishing; ANG wing excepted) | process-model.md:48 | N/A |
| 6.1.1 | 3027 | Command or field PFMs submit to AFDPO through AFIMPT, except ANG wings and subunits. | T-1 | PFM | No (ANG wing excepted, 6.1.1) | process-model.md:19,48; DECISIONS.md:103 | N/A |
| 6.1.2 | 3031 | ANG units submit fully formatted publications and forms to the local wing PFM; AFDPO does not process, post or format ANG field products. | T-3 | OPR | Yes | process-model.md:18 (stage 9); format-rules.md:8 (final mode camera-ready); DECISIONS.md:103; DECISIONS.md:24 (Q5A upload) | Covered |
| 6.1.3 | 3034 | AFDPO posts, notifies PFM/OPR/AO in AFIMPT, goal 20 business days (15 coordination plus 5 adjudication). | - | AFDPO | No (AFDPO/e-Publishing only) | - | N/A |
| 6.1.3 Note | 3037 | OPRs are encouraged to tell affected staff offices when a publication is released, revised or rescinded, alerting them to related publications. | - | OPR | Yes | list design:21 (Notice Sent event type, for rescind notices only); no release/revision notice step | Partial |
| 6.1.4 | 3041 | PMs and GMs are posted under the subject series; a GM that amends a publication is posted "on top" so users see it first, publication unaltered. | - | PFM | Yes (wing GMs) | - (no posting step or PI field for it) | Gap |
| 6.2 | 3046 | Heading: posting and printing classified or CUI products. | - | - | Partial (CUI yes; classified excluded) | - | Info |
| 6.2.1 | 3048 | Classified electronic publications may be posted on local SIPRNET sites. | - | OPR | Partial: classified excluded by PFM decision | PFM S4 (14 Nov 26): N/A, see docs/reviews/2026-11-13-coverage-gap-sweep.md | N/A |
| 6.2.2 | 3050 | CUI publications may be offered on WMS or another approved locally managed site; OPR consults security on accessibility and releasability. | - | OPR | Yes (locally managed site) | list design:35 (Access Level: Public, Restricted, CUI) | Covered |
| 6.2.3 | 3056 | OPRs ensure SIPRNET, other-site or OPR-only publications are listed under an unclassified title in the e-Publishing PI. | T-1 | OPR | No (e-Publishing PI; wing PI is 6.4.2) | process-model.md:48 | N/A |
| 6.2.4 | 3059 | AFDPO does not schedule classified or CUI products for printing; requests include justification and funding. | - | AFDPO | No (AFDPO printing only) | - | N/A |
| 6.3 | 3065 | AFDPO may correct processing and administrative errors in posted products without a 673; OPRs or local PFMs may ask AFDPO to start one. | - | AFDPO | Partial: ANG wing PFM does it locally (AFDPO does not post ANG products) | list design:18 (Corrective Action type); process-model.md:59 | Covered |
| 6.3.1 | 3068 | Notify the OPR of the proposed corrective action if it did not start it; keep the notice in the record set. | - | PFM | Yes (by analogy, 6.3.4) | list design:21 (Notice Sent event); no record-set step | Partial |
| 6.3.2 | 3070 | Annotate the front page "Corrective Actions applied on [date]". | - | PFM | Yes | Renderer gap (no F-rule; GC E5 covers forms only) | Renderer |
| 6.3.3 | 3072 | Consider adding a "Summary of Corrective Actions" section after the opening paragraph and before the summary of changes if extensive. | - | PFM | Yes | Renderer gap (no F-rule) | Renderer |
| 6.3.4 | 3075 | Units below wing or delta that post their own publications may take corrective actions the same way. | - | PFM | Partial: wing PFM follows the same steps | list design:18 | Info |
| 6.4 | 3077 | Heading: posting products issued below wing or delta level, or by ANG wings and subunits. | - | - | Yes (ANG wing named) | process-model.md:48 | Info |
| 6.4.1 | 3079 | PFMs distribute local publications and forms on approved websites or other approved methods. | T-3 | PFM | Yes | process-model.md:19,48; DECISIONS.md:103; schema PFMProductIndex.PostedLink | Covered |
| 6.4.2 | 3081 | PFMs maintain a Product Index of all applicable organizational publications and forms. | T-3 | PFM | Yes | process-model.md:19,48; schema PFMProductIndex (PFMProductIndex.json:9-180); DECISIONS.md:58; docs/sharepoint-lists.md ("What each list holds", PFM Product Index) | Covered |
| 6.5 | 3082 | Heading: establishing a Functional Publications Library (FPL). | - | - | Yes (optional) | DECISIONS.md:42 (FPL custodians left out) | Info |
| 6.5.1 | 3083 | Commanders and directors may establish FPLs holding a copy of this manual and a PI of included publications. | - | commander | Yes (optional) | DECISIONS.md:42 | Gap |
| 6.5.2 | 3086 | FPLs link to e-Publishing products; classified and CUI products may be posted directly or printed. | - | commander | Yes (optional) | DECISIONS.md:42 | Info |
| 6.5.3 | 3089 | Establish an FPL by written notice to the servicing PFM naming the activity, location and primary and alternate custodians; custodians are trained and keep contents current. | T-3 | commander | Yes (optional) | DECISIONS.md:42 (left out by PFM) | Gap |
| 6.5.4 | 3094 | FPL publications may be loaned for official use; no public viewing or borrowing; CUI may be filed with others. | - | custodian | Yes (optional) | - | Info |
| 6.5.5 | 3099 | OPRs request paper publications from DLA document services at unit expense. | - | OPR | Yes (optional) | - | Info |
| 6.5.6 | 3105 | FPL custodians review product announcements and the PI and inventory the library regularly; dispose of records per AFI 33-322. | T-3 | custodian | Yes (optional) | DECISIONS.md:42 (left out by PFM) | Gap |
| 6.6 | 3109 | All personnel process only unclassified, unrestricted information on the unclassified network. | - | all | Yes | AGENTS.md data boundary | Info |
| 6.6.1 | 3112 | OPRs send final packages (new, rewrite, IC, AC, PM, GM) to the PFM after certification and approval, with 673 (or DAF Form 399), Word/PDF draft and figure files. | T-3 / T-1 | OPR | Yes | process-model.md:18; DECISIONS.md:24 (Q5A upload, flow notifies PFM) | Covered |
| 6.6.2 | 3119 | The PFM uses AFIMPT to deliver products to AFDPO for the e-Publishing website. | T-1 | PFM | No (ANG wing posts locally, 1.1.3.2) | DECISIONS.md:103; ARCHITECTURE.md:76 | N/A |
| 6.6.2 (notify) | 3121 | AFDPO and/or PFMs notify OPRs when their publications and forms are posted and effective. | - | PFM | Yes (PFM notice) | ARCHITECTURE.md:42 (stage-advance notices to customer); no explicit posted-and-effective notice | Partial |
| 6.6.3 | 3123 | WMS is AFDPO's restricted site for products at and above wing level, excluding ANG wings and subunits; Attachments 8, 9, 13 explain accounts. | - | AFDPO | No (ANG wings excluded, 6.6.3) | format-rules.md:8 | N/A |
| 6.6.4 | 3134 | OPRs send a completed 673 for classified or CUI products to the PFM; its details list the product in the e-Publishing PI. | T-1 | OPR | Partial: 673 to the PFM yes; classified excluded | process-model.md:18; DECISIONS.md:42 | Partial |
| 6.6.5 | 3138 | Only unclassified restricted-product information goes on e-Publishing; CUI products are obtained through WMS (CAC, .mil only). | - | AFDPO | No (e-Publishing/WMS only) | - | N/A |
| 6.6.6 | 3146 | AFDPO issues physical products to DoD and agencies; monthly maximum issue; justification letters for over-maximum orders. | T-3 | AFDPO | No (AFDPO ordering only) | - | N/A |
| 6.7 | 3168 | Heading: processing publications and forms for printing. | - | - | Partial | DECISIONS.md:42 (printed products left out) | Info |
| 6.7.1 | 3169 | OPRs give written justification to create or continue printed products; convert to electronic where practicable. | T-1 | OPR | Yes | list design:30 (Printing And Distribution, added for forms 8.10.1.2 only); DECISIONS.md:42 | Partial |
| 6.7.2 | 3175 | OPR gives the local PFM a GPO Form 952, DAF Form 673, a clean printout and artwork; PFM helps with forms and graphics. | T-1 | OPR | Yes | PFM S4 (14 Nov 26): N/A, see docs/reviews/2026-11-13-coverage-gap-sweep.md | N/A |
| 6.7.3 | 3178 | PFMs ensure multicolor printing is necessary and minimal; OPR justifies extra color or printing features in the 673 "Additional Information". | T-1 | PFM | Yes | PFM S4 (14 Nov 26): N/A, see docs/reviews/2026-11-13-coverage-gap-sweep.md | N/A |
| 6.7.3 Note | 3180 | Avoid excessive printing requirements (coated paper, embossing, die-cutting, foil stamping). | - | OPR | Yes | - | Info |
| 6.7.4 | 3183 | To sell unrestricted products to the public, the OPR completes GPO Form 3868 and the local PFM sends it through SAF/AAGP. | T-2 | PFM | Yes (rare) | PFM S4 (14 Nov 26): N/A, see docs/reviews/2026-11-13-coverage-gap-sweep.md | N/A |
| 6.7.5 | 3191 | Order unclassified physical products from the Order Portal or DLA; WMS for downloads; contact the PFM for bulk printing. | - | OPR | Yes | - | Info |
| 6.7.5 Note | 3194 | Printing funds may be centralized within the local publishing function. | - | PFM | Yes | - | Info |
| 6.7.6 | 3196 | Limited distribution is requested in the 673 "Additional Information" block; large lists go through Order Portal. | - | OPR | Yes | list design:30 (Printing And Distribution) | Partial |
| 7.1 | 3209 | Records are created when members follow the processes prescribed in publications. | - | all | Yes | - | Info |
| 7.1.1 | 3211 | OPRs make sure the AF RDS shows the correct disposition of all records their publication creates. | T-1 | OPR | Yes | process-model.md:42 (Records coordinator, 7.1.3) checks it at coordination; no OPR confirmation field | Partial |
| 7.1.2 | 3213 | If the AF RDS is wrong, OPRs follow AFI 33-322 to update it. | - | OPR | Yes | - | Info |
| 7.1.3 | 3215 | The local records manager checks the processes prescribed in the publication against the AF RDS during formal coordination. | T-3 | coordinator | Yes | DECISIONS.md:16 (Q13 Records row); process-model.md:42,44; GC A2 | Covered |
| 7.1.4 | 3218 | Alert SAF/CN's Records Office when a publication prescribes analog (paper) records. | - | OPR | Yes | process-model.md:64; list design:31 (Prescribes Paper Records) | Covered |
| 7.2 | 3223 | OPRs keep the records that supported approval of the policy or guidance, electronically where possible, per AFI 33-322. | T-1 | OPR | Yes | DECISIONS.md:18 (Q15A central record sets); list design:50 (Record Sets folder) | Covered |
| 7.2.1 | 3227 | The publication record set is a separate file from the prescribed form record set; old versions' sets may be disposed. | - | OPR | Yes | schema PFMProductIndex.PublicationRecordSetLink, FormRecordSetLink (PFMProductIndex.json:173,180); list design:50; DECISIONS.md:46 (R 07) | Covered |
| 7.2.1 (Rule 01.00) | 3229 | AF RDS Table 33-38 Rule 01.00 governs disposition: DAF-wide or major/field command publications are permanent (NARA). | - | OPR | Partial: wing publications use PFM's chosen R 07 | DECISIONS.md:46 | Info |
| 7.2.2 | 3233 | Record-set keepers follow AFI 33-322 for making, maintaining and disposing of records. | - | all | Yes | DECISIONS.md:46 | Info |
| 7.2.2.1 | 3235 | HQ DAF publication OPRs keep official record sets; may delegate to MAJCOM, FLDCOM, DRU or FOA. ETMS2 is not a record set. | T-1 | OPR | No (HQ DAF OPRs only) | - | N/A |
| 7.2.2.2 | 3238 | OPRs of departmental publications authored by commands or field units keep the record set per local PFM guidance. | - | OPR | No (departmental publications only) | - | N/A |
| 7.2.2.3 | 3240 | The command or field PFM and the senior communications, information and knowledge operations manager decide who keeps record sets locally. | T-3 | PFM | Yes | DECISIONS.md:18 (Q15A); GC A20 | Covered |
| 7.2.3 | 3243 | Records owners keep a file arranged numerically by subject series for each publication and form containing the items below. | - | OPR | Yes | list design:50 (folders); GC B7 (:50 says "checklist of required items", not in the list design) | Partial |
| 7.2.3.1 | 3248 | Records of PMs and GMs converted to permanent publications join that publication's record set; others are kept like other record sets. | T-1 | OPR | Yes (GM) | - | Gap |
| 7.2.3.2 | 3252 | Keep the original 673 in the record set per local PFM guidance; a 673 shared by a publication and its form stays in the publication set with a copy in the form set. | T-1 | OPR | Yes | GC B7 (:50); list design:29 (Master DAF Form 673 Link); list design:50 (separate Publications/Forms folders). No copy step | Partial |
| 7.2.3.3 | 3261 | Record set holds the published publication with all ICs, ACs, PMs and GMs; obsolete versions go to inactive files per AF RDS. | T-1 | OPR | Yes | schema PFMPublications.DraftLink, list design:28 (Current Version Link); DECISIONS.md:46. No completeness check | Partial |
| 7.2.3.4 | 3264 | Record set holds a copy of each published version of the form. | T-1 | OPR | Yes | schema PFMProductIndex.FormRecordSetLink; list design:42 (Locked, Edition Date) | Partial |
| 7.2.3.5 | 3265 | Record set holds all documents showing coordination, comments, ICs, ACs, form revisions, rewrites, exemptions, waivers and suggestions. | T-1 | OPR | Yes | schema PFMEndorsements.CRMLink; list design:29 (Master 673, Impasse Memo links); list design:12 (Waivers) | Partial |
| 7.2.3.6 | 3268 | Record set holds copies of form-related waivers and system form approvals (8.8.5). | T-1 | OPR | Yes | list design:12 (Waiver Approval Link) | Partial |
| 7.2.3.7 | 3270 | Record set holds each 673 or DAF Form 399 used in periodic and special reviews. | T-1 | OPR | Yes | schema PFMReviews.Form399Link (PFMReviews.json:79); PFMPublications.DAFFormLink. Links only; no step files the copy in the record set (review 12 Nov; theme T5) | Partial |
| 7.2.3.8 | 3272 | Record set holds any additional forms needed to process the publication (for example DD Form 67). | T-1 | OPR | Yes | - | Gap |
| 7.3 | 3275 | Processing guides are in Attachment 5; MAJCOM/FLDCOM publications managers are centralized under ACC. | - | MAJCOM | Yes (reference only) | process-model.md:5-21 | Info |
| 7.3 Note | 3280 | The centralized MAJCOM/FLDCOM publications managers exclude ANG, which is not a MAJCOM. | - | MAJCOM | No (MAJCOM center excludes ANG) | list design:11 (ANG functional office at NGB); DECISIONS.md:8 | N/A |
| 7.4 | 3282 | Heading: publication currency and review. | - | - | Yes | - | Info |
| 7.4.1 | 3283 | OPRs keep their publications accurate and current and may review, update or certify them current at any time. | - | OPR | Yes | process-model.md:21 (Certify Current) | Info |
| 7.4.2 | 3291 | PFM starts a REVIEW task six months before the four-year anniversary month of the effective or last certified-current date, whichever is later. | T-1 | PFM | Yes | schema PFMProductIndex.NextReviewDue (PFMProductIndex.json:152-156), PFMReviews (PFMReviews.json:45); NEXT_PROMPT.md:32 (timers, flow not yet built) | Covered |
| 7.4.2 (OPR status) | 3294 | OPRs review the publication and its prescribed forms and give the status of each in AFIMPT. | T-3 | OPR | Partial: status goes to the PFM on a 399, not AFIMPT | schema PFMReviews.OPRResponse; process-model.md:21; 8.11.3.2 note (process-model.md:21) | Covered |
| 7.4.3 | 3297 | Special reviews follow changes in mission, implemented publications, law or reorganization; PFM starts a review task on request or when aware, and tracks it. | T-1 | PFM | Yes | schema PFMReviews.ReviewType Special (PFMReviews.json:29); process-model.md:62 (2.6.19); DECISIONS.md:42 (4A) | Covered |
| 7.4.4 | 3301 | OPRs get at least 30 days to assess publications and forms and answer the PFM on a DAF Form 399. | - | OPR | Yes (AFIMPT upload applies to departmental only) | process-model.md:21; schema PFMReviews.OPRResponseDue (PFMReviews.json:48), Form399Link | Covered |
| 7.4.4.1 | 3305 | Status responses are Certify Current, Requires Revision, Requires Transfer or Is Obsolete; OPRs may flag a paper form for conversion to electronic. | - | OPR | Yes | schema PFMReviews.OPRResponse (PFMReviews.json:56); style-standard.md:24. No "convertible to electronic" field | Partial |
| 7.4.4.2 | 3309 | For Certify Current on a publication and its forms, the OPR completes the steps in 7.5. | - | OPR | Yes | process-model.md:21 | Covered |
| 7.4.4.3 | 3311 | For any other status (Requires Revision, Requires Transfer, Is Obsolete, Other), the OPR reports it as follows. | - | OPR | Yes | schema PFMReviews.OPRResponse "Other"; DECISIONS.md:40 | Covered |
| 7.4.4.3.1 | 3313 | For publications not hosted on e-Publishing, report the status on a DAF Form 399; the OPR may sign as approving authority. | - | OPR | Yes | schema PFMReviews.Form399Link; process-model.md:21 | Covered |
| 7.4.4.3.2 | 3316 | OPR reports the status of publications and forms; a signed 399 is not required. | - | OPR | No (applies to e-Publishing-hosted products) | - | N/A |
| 7.4.4.3.3 | 3318 | The AO starts and completes the reported action (IC, rewrite, transfer or rescind) within 180 days. | T-3 | AO | Yes | process-model.md:21; schema PFMReviews.ActionDue (PFMReviews.json:87), FollowUpAction | Covered |
| 7.4.4.4 | 3321 | If the OPR does not answer the task, the PFM starts a rescind action and may staff a 673 to the certifier and approver. | - | PFM | Yes | process-model.md:21,67; list design:61; DECISIONS.md:40 (No Response) | Covered |
| 7.4.5 | 3324 | Any member may report errors or suggest changes on DAF Form 847 to the OPR, or through the functional chain for higher-headquarters publications. | - | all | Yes | list design:11 (PFM Recommendations, Inbound/Outbound); process-model.md:69; DECISIONS.md:8 (3) | Covered |
| 7.4.5.1 | 3332 | An office contesting published language first works with the OPR, then involves servicing legal, or elevates in its chain to the approving official. | - | commander | Yes | list design:11 (Recommendation Status, Disposition). No contest/elevation status | Partial |
| 7.4.5.2 | 3340 | The DAF OPR cannot waive DoD requirements; the contester works with the DAF OPR for the DoD issuance; courtesy copy to the AFDPO workflow box. | T-3 | OPR | No (DAF OPR/AFDPO channel, not wing) | - | N/A |
| 7.4.5.3 | 3347 | A unit whose publication conflicts with its own other publication sends a DAF Form 847 to both OPRs; OPRs de-conflict. | T-1 / T-3 | OPR | Yes | list design:11 (Product lookup holds one publication, not two OPRs) | Partial |
| 7.5 | 3352 | Heading: certification of a publication as current. | - | - | Yes | - | Info |
| 7.5.1 | 3353 | If review finds no changes, OPR and approving authority sign a DAF Form 399 and send it to the PFM; no coordination. | T-1 | OPR | Yes | process-model.md:21; PFMPublications.DAFFormLink | Covered |
| 7.5.1 Note | 3356 | A publication must meet Chapter 4 content requirements to be considered current. | - | OPR | Yes | format-rules.md (all F-rules); no gate at certify-current | Info |
| 7.5.2 | 3359 | The local PFM marks the publication "Certified Current on" plus the effective date below the published date; this starts the next four-year cycle. | - | PFM | Yes | process-model.md:21; schema PFMProductIndex.CertifiedCurrentDate (json:145), NextReviewDue. Renderer has no rule for the mark | Renderer |
| 7.5.3 | 3362 | An IC may also certify the publication current; check the "Certify Current" block on the 673 and say so in the staffing package. | - | OPR | Yes | list design:40 (Also Certifies Current); process-model.md:67 | Covered |
| 7.6 | 3365 | Required steps for a rewrite. | - | OPR | Yes | process-model.md:21 | Info |
| 7.6.1 | 3367 | Draft with the PCM and any SMEs. | - | OPR | Yes | process-model.md:11 | Covered |
| 7.6.2 | 3368 | Formal coordination annotated on the 673; actions and signatures may be transcribed to a consolidated 673. | T-1 | OPR | Yes | process-model.md:14,55 | Covered |
| 7.6.3 | 3370 | Legal coordination. | T-1 | OPR | Yes | process-model.md:15 | Covered |
| 7.6.4 | 3371 | Certifying official endorses the 673. | T-1 | certifier | Yes | process-model.md:16 | Covered |
| 7.6.5 | 3372 | Approving official endorses the 673. | T-1 | approver | Yes | process-model.md:17 | Covered |
| 7.6.6 | 3376 | Submit to the publications manager for final processing. | T-1 | OPR | Yes | process-model.md:18 | Covered |
| 7.7 | 3377 | Heading: Interim Change (IC). | - | - | Yes | - | Info |
| 7.7.1 | 3378 | An IC changes part of a publication when a full rewrite is not warranted. | - | OPR | Yes | schema PFMPublications.ActionType Interim Change | Info |
| 7.7.2 | 3380 | Rule 1: up to 10 pages of changed elements only, marked with asterisks, integrated by the PFM. | - | OPR | No (Rule 2 required for wing products, 7.7.5) | process-model.md:68 | N/A |
| 7.7.3 | 3383 | Rule 2: the entire publication with changed elements marked with asterisks, unlimited pages. | - | OPR | Partial: Rule 2 applies; asterisks replaced by margin bars (7.7.5) | process-model.md:68; list design:62; New-Publication.ps1:367 | Renderer |
| 7.7.4 | 3386 | Include a Summary of Changes under both rules. | - | OPR | Yes | format-rules F-026 | Renderer |
| 7.7.5 | 3387 | If the publication was not formatted by AFDPO (camera-ready, waivered), the OPR uses Rule 2 and gives the PFM a camera-ready Word version. | T-1 | OPR | Yes | process-model.md:68; GC A23 (:32); format-rules.md:8 (final mode camera-ready) | Covered |
| 7.7.5 Note | 3390 | Asterisks only for AFDPO-tagged drafts; waivered and camera-ready drafts get manual left-border margin bars. | - | AO | Yes | New-Publication.ps1:367 (margin bar as left border); list design:62; format-rules F-026 | Renderer |
| 7.7.6 | 3395 | ICs cannot change PMs, GMs or HQDAFMDs; reissue them in full. | - | OPR | Yes (GM) | list design:54 (an IC never changes a GM); process-model.md:66 | Covered |
| 7.7.7 | 3397 | ICs supersede or incorporate the text of any active GMs or PMs. | T-1 | OPR | Yes | list design:59; GC B9 (:52) | Covered |
| 7.7.8 | 3398 | Heading: formatting ICs. | - | - | Yes | - | Info |
| 7.7.8.1 | 3399 | Rule 1 ICs: separate Word document with short header, Summary of Changes and only the changed elements (Figure 7.1). | - | OPR | No (Rule 1 not used at wing) | - | N/A |
| 7.7.8.1.1 | 3403 | Rule 1: change whole paragraphs without renumbering; changes shown with margin bars; below-wing, camera-ready and supplement bars are added manually by the AO. | - | AO | Partial: margin-bar part applies; paragraph-only part is Rule 1 | New-Publication.ps1:367; process-model.md:68 | Renderer |
| 7.7.8.1.2 | 3414 | Rule 1: delete or replace whole figures and tables; new ones need a text reference. | - | AO | No (Rule 1 only) | - | N/A |
| 7.7.8.1.3 | 3420 | Rule 1: provide all of Attachment 1, marking changed items with asterisks. | - | AO | No (Rule 1 only) | - | N/A |
| 7.7.8.1.3 Note | 3422 | Only Attachment 1 needs asterisks in a Rule 1 IC. | - | AO | No (Rule 1 only) | - | N/A |
| 7.7.8.1.4 | 3424 | Rule 1: attachment 2 onward changes go below regular paragraphs; deleted or replaced attachments go after Attachment 1. | - | AO | No (Rule 1 only) | - | N/A |
| 7.7.8.2 | 3429 | Rule 2 ICs are full text; for products not AFDPO-formatted the AO gets the Word file from the PFM, adds the Summary of Changes and marks changes. | - | AO | Yes (file from PFM) | list design:28 (Current Version Link); format-rules F-026; New-Publication.ps1:367 | Partial |
| 7.7.8.3 | 3435 | Submit ICs in Microsoft Word, 12-point Times New Roman. | - | AO | Yes | format-rules F-001 | Renderer |
| 7.7.8.4 | 3436 | A deleted paragraph, table, figure, section, chapter or attachment keeps a placeholder citing its number and "(DELETED)". | - | AO | Yes | - (not in format-rules; renderer has no DELETED placeholder) | Renderer |
| 7.7.8.4 Note | 3438 | References to deleted content are removed and the document renumbered at a rewrite. | - | AO | Yes | - | Info |
| 7.7.8.5 | 3440 | Do not use "(Added)" in an IC; all changed and added content gets a margin bar. | - | AO | Yes | process-model.md:68; list design:62; GC A23 | Renderer |
| 7.7.9 | 3443 | Required steps for an IC. | - | OPR | Yes | process-model.md:21 | Info |
| 7.7.9.1 | 3445 | Draft with the PCM and any SMEs. | T-1 | OPR | Yes | process-model.md:11 | Covered |
| 7.7.9.2 | 3446 | Formal coordination annotated on the 673; transcription to a consolidated 673 allowed. | T-1 | OPR | Yes | process-model.md:14,55 | Covered |
| 7.7.9.3 | 3448 | Legal coordination. | T-1 | OPR | Yes | process-model.md:15 | Covered |
| 7.7.9.4 | 3449 | Certifying official endorses the 673. | T-1 | certifier | Yes | process-model.md:16 | Covered |
| 7.7.9.5 | 3450 | Approving official endorses the 673. | T-1 | approver | Yes | process-model.md:17 | Covered |
| 7.7.9.6 | 3451 | Submit to the PFM for final processing. | T-1 | OPR | Yes | process-model.md:18 | Covered |
| Figure 7.1 | 3455 | Sample Rule 1 interim change (short header, summary of changes with margin-bar sentence, changed paragraphs, deleted paragraph placeholder). | - | OPR | No (Rule 1 sample) | - | N/A |
| Figure 7.2 | 3482 | Sample Rule 2 interim change: summary of changes with asterisk and margin-bar sentence, full text with asterisked changes. | - | OPR | Partial: sample shows asterisk style used for AFDPO-tagged drafts | format-rules F-026 | Info |
| 7.8 | 3500 | Heading: Administrative Change (AC), permanent and attached. | - | - | Yes | process-model.md:21 | Info |
| 7.8.1 | 3501 | ACs do not affect content, authority, purpose or implementation; no coordination; all ACs consolidated in one document. | - | OPR | Yes | process-model.md:21 | Covered |
| 7.8.2 | 3505 | ACs cover office-symbol changes (from transfer or reorganization) and e-mail address and web link updates; other changes need a PFM waiver. | - | OPR | Yes | list design:54; IR row 17 (:100) | Covered |
| 7.8.3 | 3509 | Only the OPR or PCM may start an AC; approver is a 3-Ltr/L3 official at or above the OPR. | - | OPR | Yes | list design:54; process-model.md:59,21 | Covered |
| 7.8.4 | 3512 | ACs are not integrated; they show as first pages and are removed at the next IC or rewrite, which must include them. | T-1 | OPR | Yes | list design:59 (IC/rewrite incorporates ACs); GC B9. No posting step for the AC front pages | Partial |
| 7.8.5 | 3516 | The AC tells the reader which changes take effect, with example wording. | - | OPR | Yes | - | Info |
| 7.8.6 | 3519 | Submit the AC to the approver in Word, 12-point Times New Roman (Figure 7.3). | - | OPR | Yes | format-rules F-001 (no AC document rule) | Renderer |
| 7.8.7 | 3521 | AFDPO assigns each AC a date when posted, placed at the end of the change description. | - | PFM | Yes (local PFM posts) | - | Gap |
| 7.8.8 | 3523 | ACs are listed chronologically in one document; the OPR keeps the list and sends the complete list each time; earlier ACs keep their dates. | - | OPR | Yes | DECISIONS.md:42 (AC history left out) | Gap |
| 7.8.9 | 3531 | A new AC does not cancel earlier ones unless it says so ("Canceled" next to the old date); an IC or rewrite removes all posted ACs. | - | OPR | Yes | list design:59 (ACs incorporated at IC/rewrite); DECISIONS.md:42 | Partial |
| 7.8.10 | 3536 | Required steps for an AC. | - | OPR | Yes | process-model.md:21 | Info |
| 7.8.10.1 | 3538 | Draft with the PCM and any SMEs. | - | OPR | Yes | process-model.md:11 | Covered |
| 7.8.10.2 | 3539 | No coordination on an AC. | - | OPR | Yes | process-model.md:21 | Covered |
| 7.8.10.3 | 3540 | No certifying official endorsement on the 673. | - | OPR | Yes | process-model.md:21 | Covered |
| 7.8.10.4 | 3541 | The OPR obtains the 3-Ltr/L3 approving endorsement on the 673. | T-1 | OPR | Yes | process-model.md:21 | Covered |
| 7.8.10.5 | 3543 | The OPR submits the AC to the PFM for final processing. | T-1 | OPR | Yes | process-model.md:18 | Covered |
| Figure 7.3 | 3545 | Sample administrative change (image only; no text in extract). | - | OPR | Yes | - | Info |
| 7.9 | 3549 | Heading: Policy Memorandum (PM) and Guidance Memorandum (GM). | - | - | Yes (GM) | - | Info |
| 7.9.1 | 3550 | PMs and GMs issue or change policy or guidance quickly, only for risk to life, safety, property or mission; usable only for instructions and manuals. | - | OPR | Yes (GM) | list design:54 (GM changes only an instruction, manual or supplement); process-model.md:60,66 | Covered |
| 7.9.1 Note (one GM) | 3557 | Only one GM at each level may be active for a publication; OPRs consolidate into a single GM. | T-1 | OPR | Yes | process-model.md:60; GC A10 | Covered |
| 7.9.1 Note (attachments) | 3559 | Attachments to PMs and GMs follow the numbering and required elements of permanent publications. | - | OPR | Yes | format-rules F-011, F-036 | Renderer |
| 7.9.1.1 | 3563 | PMs are written only at HQ DAF and approved by the SecAF; no tier waiver designators. | - | HQ DAF | No (HQ DAF only) | - | N/A |
| 7.9.1.2 | 3567 | GMs may be issued at any level and are approved at that level; OPRs apply tier waiver designators to GMs; GMs are for instructions and manuals only. | T-1 | OPR | Yes | format-rules F-039, F-040 (no tier at the issuer's own level, PFM 2B); list design:54 | Renderer |
| 7.9.2 | 3574 | OPRs clearly identify the punitive nature of guidance in PMs and GMs. | T-1 | OPR | Yes | format-rules F-025 (punitive statement) | Renderer |
| 7.9.3 | 3577 | PMs and GMs are valid one year from the issue date. | - | OPR | Yes | process-model.md:60; schema PFMProductIndex.ExpirationDate (json:159), ProductStatus Expired | Covered |
| 7.9.3.1 | 3578 | OPRs may extend and reissue before expiry by re-coordinating as needed and getting certification and approval on a new 673. | - | OPR | Yes | list design:18 (Reissue Guidance Memorandum); process-model.md:59 | Covered |
| 7.9.3.2 | 3581 | OPRs may carry the guidance into a publication through a rewrite or IC. | - | OPR | Yes | list design:54 (follow-up within 1 year); process-model.md:66 | Covered |
| 7.9.3.3 | 3583 | Otherwise the PM/GM expires after one year; AFDPO removes it from e-Publishing and notifies OPR and PFM. | T-1 | PFM | Yes (wing PFM removes it) | schema PFMProductIndex.ProductStatus Expired (json:116-125); NEXT_PROMPT.md:32 (GM expiry flow). No notice or site-removal step | Partial |
| 7.9.4 | 3588 | Editable PM and GM templates are available on AFIMPT or from the PFM. | - | PFM | Yes | - | Info |
| 7.9.5 | 3589 | Required steps for a PM or GM. | - | OPR | Yes | process-model.md:21; DECISIONS.md:7 (Process Steps Applies To) | Info |
| 7.9.5.1 | 3590 | Draft with the PCM and any SMEs. | T-1 | OPR | Yes | process-model.md:11 | Covered |
| 7.9.5.2 | 3594 | Legal coordination. | T-1 | OPR | Yes | process-model.md:15,21 | Covered |
| 7.9.5.3 | 3595 | SAF/AA coordinates all PMs; not required for GMs. | - | HQ DAF | No (SAF/AA, PMs are HQ DAF only) | - | N/A |
| 7.9.5.4 | 3597 | Certifying official endorses the 673. | T-1 | certifier | Yes | process-model.md:16 | Covered |
| 7.9.5.5 | 3598 | Approving official endorses the 673. | T-1 | approver | Yes | process-model.md:17 | Covered |
| 7.9.5.6 | 3599 | Submit to the PFM for final processing. | - | OPR | Yes | process-model.md:18 | Covered |
| 7.10 | 3600 | Heading: transfer of publication responsibility. | - | - | Yes | - | Info |
| 7.10.1 | 3601 | The current approving authority gets the proposed new approving authority's concurrence before any other action. | T-1 | approver | Yes | process-model.md:59; GC A18 | Covered |
| 7.10.2 | 3606 | The current OPR staffs a package to the proposed new approving official for acceptance or rejection; if accepted, the 673 reflects it. | T-2 | OPR | Yes | process-model.md:59; DECISIONS.md:7 | Covered |
| 7.10.3 | 3609 | SecAF approves transfer of SecAF-assigned responsibilities and a PD's certifier change. | - | HQ DAF | No (SecAF/HQ DAF only) | - | N/A |
| 7.10.3 Note | 3610 | Policy document transfers use an eSSS or SecAF memorandum. | - | HQ DAF | No (SecAF/HQ DAF only) | - | N/A |
| 7.10.4 | 3613 | Refer to HOI 90-1 for transferring DoD issuances. | - | HQ DAF | No (DoD issuances) | - | N/A |
| 7.10.5 | 3615 | The gaining OPR revises the number (if the series changes), certifier and approver details; the record set moves to the gaining OPR or PFM. | - | OPR | Yes | DECISIONS.md:18 (central record sets, no move needed inside the wing); no gate on the number and officials revision | Partial |
| 7.10.6 | 3623 | Required steps for a transfer, done by the losing OPR. | - | OPR | Yes | process-model.md:59 | Info |
| 7.10.6.1 | 3625 | Draft the package with any SMEs. | T-1 | OPR | Yes | process-model.md:11 | Covered |
| 7.10.6.2 | 3626 | Coordinate with the gaining office. | T-1 | OPR | Yes | process-model.md:59 (new approving authority's concurrence first) | Covered |
| 7.10.6.3 | 3627 | The losing approving official signs as certifying official on the 673. | T-1 | approver | Yes | - (transfer signer roles not recorded; process-model.md:57 is the normal certifier rule) | Partial |
| 7.10.6.4 | 3628 | The gaining approving official signs as approving official on the 673. | T-1 | approver | Yes | - (as 7.10.6.3) | Partial |
| 7.10.6.5 | 3630 | Submit to the PFM for final processing. | T-1 | OPR | Yes | process-model.md:18 | Covered |
| 7.10.7 | 3634 | Changing only the OPR is finalized by the certifier or approver and reported to local PFMs; the product is updated promptly; use AF Form 1768, memo or 673; no outside coordination. | - | certifier | Yes | list design:18 (Change OPR action); GC B11 (:54) | Covered |
| 7.11 | 3639 | A publication becomes obsolete when rescinded, superseded or expired. | - | all | Yes | schema PFMProductIndex.ProductStatus (json:116) | Info |
| 7.11.1 | 3641 | AFDPO (or PFMs for local sites) removes obsolete products from the active PI and removes links; OPRs notify affected staff offices. | - | PFM | Yes (PFM, local site) | schema PFMProductIndex.ProductStatus; DECISIONS.md:46 (view "PFM - Not Active"); list design:21 (Notice Sent). No site-link removal step | Partial |
| 7.11.2 | 3647 | Supplements may become obsolete when a new higher-headquarters publication says all supplements are obsolete. | - | OPR | Yes | process-model.md:62 (special review per implementing row); schema PFMProductIndex.ParentPublication | Partial |
| 7.11.3 | 3650 | Obsolete products are listed in the obsolete PI with the action taken and a link to any superseding product. | - | PFM | Yes | schema PFMProductIndex.ProductStatus, SupersededBy (json:98), InactiveDate | Covered |
| 7.11.4 | 3653 | ANG notifies subscribers of obsolete publications. | - | PFM | Yes (ANG named) | process-model.md:61; list design:61 (notices), :21 (Notice Sent) | Covered |
| 7.11.5 | 3654 | A rescission removes a publication with no replacement (consider first); the OPR completes coordination, certification and approval on the 673. | T-1 | OPR | Yes | schema PFMPublications.ActionType Rescind; list design:61; process-model.md:61 | Covered |
| 7.11.5.1 | 3658 | The OPR sends the signed 673 to the PFM; the AO writes disposition instructions on it (classified per AFI 33-322). | - | AO | Yes | DECISIONS.md:46 (records rule); no disposition-instruction field | Partial |
| 7.11.5.2 | 3661 | If the publication prescribes a form or data collection tool, say so on the 673 and copy the request to the information reports management and control office; unretained forms become obsolete. | - | OPR | Yes | process-model.md:61; list design:37 (Retained Forms Relinked) | Covered |
| 7.11.5.2 Note | 3663 | Rescission obsoletes prescribed forms unless first moved to another directive publication; implementing and supplementing publications are reviewed for currency. | - | OPR | Yes | list design:37,61; process-model.md:62 | Covered |
| 7.11.5.3 | 3667 | Only the SecAF may approve rescission of policy issuances. | - | approver | No (SecAF, HQ DAF only) | - | N/A |
| 7.11.5.4 | 3669 | Guidance publications and GMs are rescinded by the issuing HQ DAF 2-Ltr/L2; DoD-implementing publications need SAF/AAGP coordination. | - | approver | No (HQ DAF only) | - | N/A |
| 7.11.5.5 | 3678 | After no review response, the PFM may start a rescind action and staffs a 673 to the certifier and approver only; the signed 673 goes to the OPR for closeout. | - | PFM | Yes | process-model.md:67; list design:61; schema PFMReviews.OPRResponse "No Response" (DECISIONS.md:40) | Covered |
| 7.11.5.6 | 3683 | Requirements HQ DAF rescinds or makes optional are not replaced by comparable instructions at lower levels. | - | OPR | Yes | - (no check at request) | Gap |
| 7.11.5.7 | 3688 | To keep specific sections, issue a GM relocating the guidance to another publication, then rescind. | - | OPR | Yes | list design:37 (Directive Guidance Moved); list design:61 | Covered |
| 7.11.5.7.1 | 3692 | GMs get expedited coordination (legal, certifier, approver). | - | OPR | Yes | process-model.md:21 | Info |
| 7.11.5.7.2 | 3694 | GMs give the HQ DAF 2-Ltr/L2 one year to consolidate guidance elsewhere, unless extended. | - | HQ DAF | Yes (wing equivalent) | list design:54 (follow-up action within 1 year) | Info |
| 7.11.5.8 | 3696 | Rescission does not end records duties; records created under the publication are kept and disposed of legally per AFI 33-322. | - | OPR | Yes | DECISIONS.md:46 (R 07 trigger on Rescinded) | Covered |
| 7.11.6 | 3700 | Heading: superseded publications. | - | - | Yes | - | Info |
| 7.11.6.1 | 3701 | Issuing a new or revised publication includes the supersession; the new publication and 673 (Section I, block 8) identify it as superseded. | - | OPR | Yes | format-rules F-022 (Supersedes line); schema PFMProductIndex.SupersededBy | Covered |
| 7.11.6.2 | 3705 | Superseding at publication lets the PFM remove the old product without a separate rescind action. | - | PFM | Yes | schema PFMProductIndex.ProductStatus Superseded | Covered |
| 7.11.7 | 3707 | Heading: expired publications. | - | - | Yes | - | Info |
| 7.11.7.1 | 3708 | PMs and GMs expire one year after publication. | - | OPR | Yes (GM) | process-model.md:60; schema PFMProductIndex.ExpirationDate | Covered |
| 7.11.7.2 | 3709 | Outdated supplements to DoD issuances not otherwise extended are expired and obsolete. | - | OPR | No (DoD-issuance supplements are HQ DAF) | - | N/A |
| 7.11.7.3 | 3711 | Expired PMs, GMs, supplements and implementing publications come off e-Publishing; their prescribed forms become obsolete; no 673, so use the expiration notice (or this manual for locally hosted products). | - | PFM | Yes (locally hosted) | schema PFMProductIndex.ProductStatus Expired. Expiry does not cascade to prescribed forms (cascade is rescind only, process-model.md:61) | Partial |

## Gaps

Gap and Partial rows, plus Renderer rows marked "Renderer gap". Severity: high = blocks a correct ANG wing publication or form action; medium = a required step or record not tracked; low = advisory or rare. No row is high: every high-impact rule in this range (coordination order, legal last, nonconcur gate, certify/approve, 365-day re-coordination, GM limits, rescind, review timers) has a plan location. Rows the PFM already left out by decision (DECISIONS.md:42, row 5: printed products, FPL custodians, AC history, classified products) are marked "PFM-excluded".

| Para | Line | What is missing | Severity | Suggested fix |
|---|---|---|---|---|
| 6.1.4 | 3041 | Posting a GM "on top" of the publication it amends, publication unaltered; no posting step or field | medium | PFM Process Steps posting step (Applies To: Guidance Memorandum); PFM Product Index "Amends" check on the posting gate; flow rule in docs/flow-rules.md |
| 7.2.3 (and 7.2.3.2-.6) | 3243-3268 | No checklist of required record-set contents (GC B7 promises one; list design s4 has folders only); no copy of a shared 673 into the form set; no filing of endorsement originals | medium | Add a Record Set Checklist to PFM Guidance or Process Steps, plus a posting/closeout gate on PFM Publications (Yes/No per item) |
| 5.1.5 (originals) | 2763 | No rule that the original endorsement documents are filed in the record set | medium | Same record-set checklist; add Endorsement Original Filed (yes/no) or a folder rule on PFM Endorsements |
| 7.2.3.1 | 3248 | PM/GM records are not carried into the permanent publication's record set | low | Record-set checklist item; note on the IC/rewrite gate |
| 7.2.3.8 | 3272 | Additional processing forms (for example DD Form 67) not in the record set | low | Record-set checklist item |
| 6.3.2 / 6.3.3 | 3070, 3072 | Renderer gap: front-page "Corrective Actions applied on [date]" and optional "Summary of Corrective Actions" section | medium | Add F-rules to docs/format-rules.md and renderer for Action Type = Corrective Action |
| 6.3.1 | 3068 | Notice to the OPR of a corrective action and its filing in the record set | low | Flow rule: Notice Sent event plus record-set item |
| 7.5.2 | 3359 | Renderer gap: "Certified Current on [date]" line below the published date | medium | New format rule (post-certify mark); Certify Current posting step |
| 7.7.8.4 | 3436 | Renderer gap: "(DELETED)" placeholder for deleted elements in a Rule 2 IC | low | Add F-rule and renderer support; Test-Publication check |
| 7.7.3 / 7.7.5 note / 7.7.8.5 | 3383, 3390, 3440 | Renderer: margin bars exist (New-Publication.ps1:367); no validator rule bans asterisks and "(Added)" in wing ICs (GC A23 backlog) | medium | Add F-rules (no asterisk, no "(Added)", margin bar present on changed paragraphs) to format-rules.md and Test-Publication.ps1 |
| 7.8.7 | 3521 | Date assigned to each AC at posting (AFDPO job; the wing PFM does it locally) | low | Add Posted Date on the AC action; posting step |
| 7.8.8 | 3523 | Chronological AC list, "Canceled" marks, complete list sent to approver (PFM-excluded: AC history) | low | If the PFM reverses the exclusion: AC list on PFM Product Index (multi-line) or a small PFM Admin Changes list |
| 7.8.4 / 7.8.9 | 3512, 3531 | Posting AC first pages and removing all posted ACs at the next IC/rewrite | low | Posting and IC/rewrite gate item "ACs removed from site" |
| 5.3 (POC) / 5.5 | 2827, 2880 | Coordinator POC/AO may not be a contractor or indirect-hire foreign national; no field or check | low | Add POC and POC Is Contractor Or Foreign National flag to PFM Endorsements, or a line in the CRM template and PFM Guidance |
| 5.4.4 | 2870 | No field naming which comments are the basis for a nonconcur (CRM text instructs it) | low | CRM column or PFM Endorsements note; or keep in CRM instruction text |
| 5.5.2.2 Note | 2914 | Impasse over a supplement versus the guidance it supplements goes to the higher-headquarters approving official | low | Gate text in the nonconcur step when Publication Type = Supplement; PFM Guidance row |
| 5.5.3.2 | 2921 | New 673 entry for the nonconcurring office when comments are accepted in full | low | Prompt in the resolution step (flow rule) |
| 5.2.2 | 2814 | Open question: does the 30 calendar days (written for guard and reserve applicability) cover wing-to-unit coordination | medium | PFM decision: add to DECISIONS.md; Coordination Suspense rule by Coordination Role |
| 5.1.6 / 5.1.6 Note | 2767, 2770 | No warning or gate that classified information stays off the unclassified lists (classified is PFM-excluded) | low | Warning text in PFM Guidance for the AO intake screen; Access Level choice note |
| 5.7.6.3 | 3013 | No check that the approving official is the commander, director or acting equivalent below HQ DAF/MAJCOM | low | PFM Guidance text and PFM review at approval; optional Approver Is Commander Or Director (yes/no) |
| 6.1.3 Note | 3037 | Notice to affected staff offices when a publication is released, revised or rescinded (encouraged; Notice Sent covers rescind only) | low | Extend the Notice Sent event to posting for every action type |
| 6.6.2 (notify) | 3121 | No explicit "posted and effective" notice to the OPR/AO | medium | Posting flow rule: notify Requester, AO and OPR with the link and effective date; log Notice Sent |
| 6.6.4 | 3134 | Classified/CUI 673 details used to list the product in the PI; classified is PFM-excluded | low | Keep CUI listing via Access Level; classified stays excluded |
| 6.2.1 | 3048 | Classified publications on SIPRNET (PFM-excluded) | low | None unless the PFM reverses the exclusion |
| 6.5.1 / 6.5.3 / 6.5.6 | 3083, 3089, 3105 | Functional Publications Library notices, custodians, reviews (PFM-excluded; optional) | low | If wanted: FPL list (activity, location, custodians, date notified) |
| 6.7.1 / 6.7.6 | 3169, 3196 | Printed-product justification and limited distribution tracked only for forms (Printing And Distribution) | low | Reuse Printing And Distribution for publications; PFM Guidance text |
| 6.7.2 / 6.7.3 / 6.7.4 | 3175, 3178, 3183 | GPO Form 952, multicolor justification, GPO Form 3868 for sale to public (PFM-excluded printed products) | low | PFM Guidance entries for the local PFM printing checklist |
| 7.1.1 | 3211 | OPR confirmation that the AF RDS shows correct disposition | low | Records coordinator row exists; add a Records Checked (yes/no) on PFM Endorsements or PFM Guidance text |
| 7.4.4.1 | 3305 | OPR flag that a paper form or publication can convert to electronic | low | Add Convertible To Electronic (yes/no) to PFM Reviews |
| 7.4.5.1 | 3332 | Contest path (OPR, then legal, then chain to approving official) not a status | low | Add Contested/Elevated values to Recommendation Status in PFM Recommendations |
| 7.4.5.3 | 3347 | A conflict between two of the unit's publications needs both OPRs named; PFM Recommendations holds one Product | low | Add Second Product lookup or Conflicting Publication text on PFM Recommendations |
| 7.7.8.2 | 3429 | Giving the AO the current Word file from the PFM for a Rule 2 IC | low | Current Version Link on the action (list design:28) is the source; add the step to PFM Process Steps (IC) |
| 7.9.3.3 / 7.11.1 | 3583, 3641 | Removing expired/obsolete products from the wing site, removing links, announcing, notifying the OPR | medium | Flow rule on Product Status = Expired/Superseded/Rescinded: task for PFM to remove links, Notice Sent to OPR and subscribers (7.11.4) |
| 7.11.2 | 3647 | Supplements made obsolete when a new higher-headquarters publication says so | low | Special review (process-model.md:62) plus Product Status Rescinded; gate text in the review step |
| 7.11.7.3 | 3711 | Expiry of a GM does not cascade to forms it prescribes | medium | Extend the rescind cascade (Retained Forms Relinked) to Expired; flow rule on ExpirationDate |
| 7.11.5.1 | 3658 | AO disposition instructions for the rescinded publication (673 Additional Information) | low | Disposition Instructions note on the Rescind action, or PFM Guidance text |
| 7.11.5.6 | 3683 | Do not replace HQ DAF-rescinded requirements with lower-level instructions | low | Request-time check on Action Type = New/Rewrite (question "Replaces a requirement HQ DAF rescinded?") |
| 7.10.5 | 3615 | Gaining OPR revises number, certifier and approver on transfer; record set moves (central under Q15A, so only the revisions need a gate) | low | Transfer gate: Number, Certifying Official, Approving Official updated before posting |
| 7.10.6.3 / 7.10.6.4 | 3627, 3628 | On a transfer the losing approver signs as certifier and the gaining approver as approver | low | Transfer step text in PFM Process Steps; skip the one-level-above certifier rule for Action Type = Transfer |
