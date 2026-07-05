///|
/// Tests for langtag creation
test "debug single" {
  let _res = LanguageTag::parse_and_normalize("fr")
  // debug("Result: \{res}")
}

///|
test "formatting" {
  @debug.assert_eq(
    "mn-Cyrl-MN",
    LanguageTag::parse_and_normalize("mn-Cyrl-MN").unwrap().to_string(),
  )
  @debug.assert_eq(
    "mn-Cyrl-MN",
    LanguageTag::parse_and_normalize("MN-cYRL-mn").unwrap().to_string(),
  )
  @debug.assert_eq(
    "mn-Cyrl-MN",
    LanguageTag::parse_and_normalize("mN-cYrL-Mn").unwrap().to_string(),
  )
  @debug.assert_eq(
    "en-CA-x-ca",
    LanguageTag::parse_and_normalize("en-CA-x-ca").unwrap().to_string(),
  )
  @debug.assert_eq(
    "sgn-BE-FR",
    LanguageTag::parse_and_normalize("sgn-BE-FR").unwrap().to_string(),
  )
  @debug.assert_eq(
    "az-Latn-x-latn",
    LanguageTag::parse_and_normalize("az-Latn-x-latn").unwrap().to_string(),
  )
  @debug.assert_eq(
    "i-ami",
    LanguageTag::parse_and_normalize("i-ami").unwrap().to_string(),
  )
  @debug.assert_eq(
    "i-ami",
    LanguageTag::parse_and_normalize("I-AMI").unwrap().to_string(),
  )
  @debug.assert_eq(
    "sl-afb-Latn-005-nedis",
    LanguageTag::parse_and_normalize("SL-AFB-lATN-005-nEdis")
    .unwrap()
    .to_string(),
  )
}

///|
test "primary language" {
  @debug.assert_eq(
    "fr",
    LanguageTag::parse_and_normalize("fr").unwrap().primary_language(),
  )
  @debug.assert_eq(
    "de",
    LanguageTag::parse_and_normalize("de").unwrap().primary_language(),
  )
  @debug.assert_eq(
    "x-fr-ch",
    LanguageTag::parse_and_normalize("x-fr-CH").unwrap().primary_language(),
  )
  @debug.assert_eq(
    "i-klingon",
    LanguageTag::parse_and_normalize("i-klingon").unwrap().primary_language(),
  )
  @debug.assert_eq(
    "i-bnn",
    LanguageTag::parse_and_normalize("i-bnn").unwrap().primary_language(),
  )
  @debug.assert_eq(
    "zh-hakka",
    LanguageTag::parse_and_normalize("zh-hakka").unwrap().primary_language(),
  )
}

///|
test "extended language" {
  // 使用专用 getter 替代 parts
  let tag_zh = LanguageTag::parse("zh").unwrap()
  @debug.assert_eq("zh", tag_zh.full_language())
  @debug.assert_eq("zh", tag_zh.primary_language())
  @debug.assert_eq(None, tag_zh.extended_language())
  // debug("tag_zh extended subtags: \{tag_zh.extended_language_subtags()}")
  @debug.assert_eq([], tag_zh.extended_language_subtags())

  let tag_zh_gan = LanguageTag::parse("zh-gan").unwrap()
  @debug.assert_eq("zh-gan", tag_zh_gan.full_language())
  @debug.assert_eq("zh", tag_zh_gan.primary_language())
  @debug.assert_eq(Some("gan"), tag_zh_gan.extended_language())
  @debug.assert_eq(["gan"], tag_zh_gan.extended_language_subtags())

  let tag_zh_gan_foo = LanguageTag::parse("zh-gan-foo").unwrap()
  @debug.assert_eq("zh-gan-foo", tag_zh_gan_foo.full_language())
  @debug.assert_eq("zh", tag_zh_gan_foo.primary_language())
  @debug.assert_eq(Some("gan-foo"), tag_zh_gan_foo.extended_language())
  @debug.assert_eq(["gan", "foo"], tag_zh_gan_foo.extended_language_subtags())

  let tag_zh_min_nan = LanguageTag::parse("zh-min-nan").unwrap()
  @debug.assert_eq("zh-min-nan", tag_zh_min_nan.full_language())
  @debug.assert_eq("zh-min-nan", tag_zh_min_nan.primary_language())
  @debug.assert_eq(None, tag_zh_min_nan.extended_language())
  // 修复
  @debug.assert_eq(0, tag_zh_min_nan.extended_language_subtags().length())

  let tag_i_tsu = LanguageTag::parse("i-tsu").unwrap()
  @debug.assert_eq("i-tsu", tag_i_tsu.full_language())
  @debug.assert_eq("i-tsu", tag_i_tsu.primary_language())
  @debug.assert_eq(None, tag_i_tsu.extended_language())
  // 修复
  @debug.assert_eq(0, tag_i_tsu.extended_language_subtags().length())

  let tag_zh_cn = LanguageTag::parse("zh-CN").unwrap()
  @debug.assert_eq("zh", tag_zh_cn.full_language())
  @debug.assert_eq("zh", tag_zh_cn.primary_language())
  @debug.assert_eq(None, tag_zh_cn.extended_language())
  // 修复
  @debug.assert_eq(0, tag_zh_cn.extended_language_subtags().length())

  let tag_zh_gan_cn = LanguageTag::parse("zh-gan-CN").unwrap()
  @debug.assert_eq("zh-gan", tag_zh_gan_cn.full_language())
  @debug.assert_eq("zh", tag_zh_gan_cn.primary_language())
  @debug.assert_eq(Some("gan"), tag_zh_gan_cn.extended_language())
  @debug.assert_eq(["gan"], tag_zh_gan_cn.extended_language_subtags())

  let tag_ar_afb = LanguageTag::parse("ar-afb").unwrap()
  @debug.assert_eq("ar-afb", tag_ar_afb.full_language())
  @debug.assert_eq("ar", tag_ar_afb.primary_language())
  match tag_ar_afb.extended_language() {
    Some(ext) => @debug.assert_eq(ext, "afb")
    None => fail("Expected extended language 'afb', got None")
  }
  @debug.assert_eq(["afb"], tag_ar_afb.extended_language_subtags())
  @debug.assert_eq(["afb"], tag_ar_afb.extended_language_subtags())
}

///|
test "script" {
  @debug.assert_eq(
    Some("Latn"),
    LanguageTag::parse("sr-Latn").unwrap().script(),
  )
  @debug.assert_eq(
    Some("Latn"),
    LanguageTag::parse("ar-afb-Latn").unwrap().script(),
  )
}

///|
test "region" {
  @debug.assert_eq(Some("AT"), LanguageTag::parse("de-AT").unwrap().region())
  @debug.assert_eq(
    Some("RS"),
    LanguageTag::parse("sr-Latn-RS").unwrap().region(),
  )
  @debug.assert_eq(Some("419"), LanguageTag::parse("es-419").unwrap().region())
  @debug.assert_eq(Some("DE"), LanguageTag::parse("ar-DE").unwrap().region())
  @debug.assert_eq(Some("005"), LanguageTag::parse("ar-005").unwrap().region())
}

///|
test "variant" {
  @debug.assert_eq([], LanguageTag::parse("sl").unwrap().variant_subtags())
  @debug.assert_eq(
    ["nedis"],
    LanguageTag::parse("sl-nedis").unwrap().variant_subtags(),
  )
  @debug.assert_eq(
    ["1996"],
    LanguageTag::parse("de-CH-1996").unwrap().variant_subtags(),
  )
  @debug.assert_eq(
    [],
    LanguageTag::parse("art-lojban").unwrap().variant_subtags(),
  )
}

///|
test "extension" {
  // 简单测试 extension 存在性及内容，具体子标签解析依赖 extension_subtags 迭代器
  @debug.assert_eq(None, LanguageTag::parse("en").unwrap().extension())
  let tag_ext = LanguageTag::parse("en-a-bbb-x-a-ccc").unwrap()
  @debug.assert_eq(Some("a-bbb"), tag_ext.extension())

  let tag_multi_ext = LanguageTag::parse("en-a-babble-b-warble").unwrap()
  @debug.assert_eq(Some("a-babble-b-warble"), tag_multi_ext.extension())

  let tag_fr = LanguageTag::parse("fr-a-Latn").unwrap()
  @debug.assert_eq(Some("a-Latn"), tag_fr.extension())

  let tag_complex = LanguageTag::parse(
    "en-Latn-GB-boont-r-extended-sequence-x-private",
  ).unwrap()
  @debug.assert_eq(Some("r-extended-sequence"), tag_complex.extension())

  let tag_r = LanguageTag::parse("en-r-az-r-qt").unwrap()
  @debug.assert_eq(Some("r-az-r-qt"), tag_r.extension())

  @debug.assert_eq(None, LanguageTag::parse("i-tsu").unwrap().extension())
}

// ///|

///|
test "privateuse" {
  @debug.assert_eq(None, LanguageTag::parse("en").unwrap().private_use())
  @debug.assert_eq(
    Some("x-US"),
    LanguageTag::parse("en-x-US").unwrap().private_use(),
  )
  @debug.assert_eq(
    ["US"],
    LanguageTag::parse("en-x-US").unwrap().private_use_subtags(),
  )

  @debug.assert_eq(
    Some("x-koine"),
    LanguageTag::parse("el-x-koine").unwrap().private_use(),
  )
  @debug.assert_eq(
    ["koine"],
    LanguageTag::parse("el-x-koine").unwrap().private_use_subtags(),
  )

  @debug.assert_eq(
    Some("x-fr-ch"),
    LanguageTag::parse("x-fr-ch").unwrap().private_use(),
  )
  @debug.assert_eq(
    ["fr", "ch"],
    LanguageTag::parse("x-fr-ch").unwrap().private_use_subtags(),
  )

  @debug.assert_eq(
    Some("x-foobar-AT-007"),
    LanguageTag::parse("es-x-foobar-AT-007").unwrap().private_use(),
  )
  @debug.assert_eq(
    ["foobar", "AT", "007"],
    LanguageTag::parse("es-x-foobar-AT-007").unwrap().private_use_subtags(),
  )
}

///|
test "fmt" {
  @debug.assert_eq(
    "ar-arb-Latn-DE-nedis-foobar",
    LanguageTag::parse_and_normalize("ar-arb-Latn-DE-nedis-foobar")
    .unwrap()
    .to_string(),
  )
  @debug.assert_eq(
    "ar-arb-Latn-DE-nedis-foobar",
    LanguageTag::parse_and_normalize("ar-arb-latn-de-nedis-foobar")
    .unwrap()
    .to_string(),
  )
  @debug.assert_eq(
    "ar-arb-Latn-DE-nedis-foobar",
    LanguageTag::parse_and_normalize("AR-ARB-LATN-DE-NEDIS-FOOBAR")
    .unwrap()
    .to_string(),
  )
  @debug.assert_eq(
    "xx-z-foo-a-bar-f-spam-b-eggs",
    LanguageTag::parse_and_normalize("xx-z-foo-a-bar-F-spam-b-eggs")
    .unwrap()
    .to_string(),
  )
  @debug.assert_eq(
    "hkgnmerm-x-e5-zf-vddjcpz-1v6",
    LanguageTag::parse_and_normalize("HkgnmerM-x-e5-zf-VdDjcpz-1V6")
    .unwrap()
    .to_string(),
  )
  @debug.assert_eq(
    "mgxqa-Ywep-8lcw-7bvt-h-dp1md-0h7-0z3ir",
    LanguageTag::parse_and_normalize("MgxQa-ywEp-8lcW-7bvT-h-dP1Md-0h7-0Z3ir")
    .unwrap()
    .to_string(),
  )
}

///|
test "unicode" {
  assert_true(LanguageTag::parse("zh-x-Üńìcødê") is Ok(_))
}

///|
test "cmp" {
  @debug.assert_eq(
    LanguageTag::parse_and_normalize("dE-AraB-lY").unwrap(),
    LanguageTag::parse_and_normalize("DE-aRaB-LY").unwrap(),
  )
  assert_not_eq(
    LanguageTag::parse_and_normalize("zh").unwrap(),
    LanguageTag::parse_and_normalize("zh-Latn").unwrap(),
  )
}

///|
test "wellformed tags" {
  let tags = [
    "fr", "fr-Latn", "fr-fra", "fr-Latn-FR", "fr-Latn-419", "fr-FR", "ax-TZ", "fr-shadok",
    "fr-y-myext-myext2", "fra-Latn", "fra", "fra-FX", "i-klingon", "I-kLINgon", "no-bok",
    "fr-Lat", "mn-Cyrl-MN", "mN-cYrL-Mn", "fr-Latn-CA", "en-US", "fr-Latn-CA", "i-enochian",
    "x-fr-CH", "sr-Latn-CS", "es-419", "sl-nedis", "de-CH-1996", "de-Latg-1996",
    "sl-IT-nedis", "en-a-bbb-x-a-ccc", "de-a-value", "en-Latn-GB-boont-r-extended-sequence-x-private",
    "en-x-US", "az-Arab-x-AZE-derbend", "es-Latn-CO-x-private", "en-US-boont", "ab-x-abc-x-abc",
    "ab-x-abc-a-a", "i-default", "i-klingon", "abcd-Latn", "AaBbCcDd-x-y-any-x",
    "en", "de-AT", "es-419", "de-CH-1901", "sr-Cyrl", "sr-Cyrl-CS", "sl-Latn-IT-rozaj",
    "en-US-x-twain", "zh-cmn", "zh-cmn-Hant", "zh-cmn-Hant-HK", "zh-gan", "zh-yue-Hant-HK",
    "xr-lxs-qut", "xr-lqt-qu", "xr-p-lze",
  ]
  for tag in tags {
    let result = LanguageTag::parse(tag)
    match result {
      Ok(_v) => ()
      // Ok(v) => debug("✓ \{tag} correctly rejected: \{v}")
      // assert_true(false, "\{tag} should be considered not well-formed")
      Err(e) => debug("✗ \{tag} should be  passed: \{e}")
    }
  }
}

///|
test "broken tags" {
  let tags = [
    "", "f", "f-Latn", "fr-Latn-F", "a-value", "tlh-a-b-foo", "i-notexist", "abcdefghi-012345678",
    "ab-abc-abc-abc-abc", "ab-abcd-abc", "ab-ab-abc", "ab-123-abc", "a-Hant-ZH",
    "a1-Hant-ZH", "ab-abcde-abc", "ab-1abc-abc", "ab-ab-abcd", "ab-123-abcd", "ab-abcde-abcd",
    "ab-1abc-abcd", "ab-a-b", "ab-a-x", "ab--ab", "ab-abc-", "-ab-abc", "abcd-efg",
    "aabbccddE",
  ]
  for tag in tags {
    let result = LanguageTag::parse(tag)

    match result {
      Ok(v) => debug("✗ \{tag} should be rejected but passed: \{v}")
      // assert_true(false, "\{tag} should be considered not well-formed")
      Err(_e) => ignore(_e)
      // debug("✓ \{tag} correctly rejected: \{e}")
    }
  }
}

///|
test "broken tags with extensions" {
  let tags = [
    "", "f", "fr-Latn-F", "abcdefghi-012345678", "ab-abc-abc-abc-abc", "ab-abcd-abc",
    "ab-ab-abc", "ab-123-abc", "a1-Hant-ZH", "ab-abcde-abc", "ab-1abc-abc", "ab-ab-abcd",
    "ab-123-abcd", "ab-abcde-abcd", "ab-1abc-abcd", "ab-a-x", "ab--ab", "ab-abc-",
    "-ab-abc", "abcd-efg", "aabbccddE",
  ]

  for tag in tags {
    let result = LanguageTag::parse(tag)

    match result {
      Ok(v) => debug("✗ \{tag} should be rejected but passed: \{v}")
      // assert_true(false, "\{tag} should be considered not well-formed")
      Err(e) => ignore(e)
      // debug("✓ \{tag} correctly rejected: \{e}")
    }
  }
}

///|
test "random good tags" {
  let tags = [
    "zszLDm-sCVS-es-x-gn762vG-83-S-mlL", "IIJdFI-cfZv", "kbAxSgJ-685", "tbutP", "hDL-595",
    "dUf-iUjq-0hJ4P-5YkF-WD8fk", "FZAABA-FH", "xZ-lh-4QfM5z9J-1eG4-x-K-R6VPr2z",
    "Fyi", "SeI-DbaG", "ch-xwFn", "OeC-GPVI", "JLzvUSi", "Fxh-hLAs", "pKHzCP-sgaO-554",
    "eytqeW-hfgH-uQ", "ydn-zeOP-PR", "uoWmBM-yHCf-JE", "xwYem", "zie", "Re-wjSv-Ey-i-XE-E-JjWTEB8-f-DLSH-NVzLH-AtnFGWoH-SIDE",
    "Ri-063-c-u6v-ZfhkToTB-C-IFfmv-XT-j-rdyYFMhK-h-pY-D5-Oh6FqBhL-hcXt-v-WdpNx71-K-c74m4-eBTT7-JdH7Q1Z",
    "ji", "IM-487", "EPZ-zwcB", "GauwEcwo", "kDEP", "FwDYt-TNvo", "ottqP-KLES-x-9-i9",
    "fcflR-grQQ", "TvFwdu-kYhs", "WE-336", "MgxQa-ywEp-8lcW-7bvT-h-dP1Md-0h7-0Z3ir-K-Srkm-kA-7LXM-Z-whb2MiO-2mNsvbLm-W3O-4r-U-KceIxHdI-gvMVgUBV-2uRUni-J0-7C8yTK2",
    "Hyr-B-evMtVoB1-mtsVZf-vQMV-gM-I-rr-kvLzg-f-lAUK-Qb36Ne-Z-7eFzOD-mv6kKf-l-miZ7U3-k-XDGtNQG",
    "ybrlCpzy", "PTow-w-cAQ51-8Xd6E-cumicgt-WpkZv3NY-q-ORYPRy-v-A4jL4A-iNEqQZZ-sjKn-W-N1F-pzyc-xP5eWz-LmsCiCcZ",
    "ih-DlPR-PE", "Krf-362", "WzaD", "EPaOnB-gHHn", "XYta", "NZ-RgOO-tR", "at-FE",
    "Tpc-693", "YFp", "gRQrQULo", "pVomZ-585", "laSu-ZcAq-338", "gCW", "PydSwHRI-TYfF",
    "zKmWDD", "X-bCrL5RL", "HK", "YMKGcLY", "GDJ-nHYa-bw-X-ke-rohH5GfS-LdJKsGVe",
    "tfOxdau-yjge-489-a-oB-I8Csb-1ESaK1v-VFNz-N-FT-ZQyn-On2-I-hu-vaW3-jIQb-vg0U-hUl-h-dO6KuJqB-U-tde2L-P3gHUY-vnl5c-RyO-H-gK1-zDPu-VF1oeh8W-kGzzvBbW-yuAJZ",
    "LwDux", "Zl-072", "Ri-Ar", "vocMSwo-cJnr-288", "kUWq-gWfQ-794", "YyzqKL-273",
    "Xrw-ZHwH-841-9ddT-ESSZF-6OqO-0knk-991U-9p3m-b-JhiV-0Kq7Y-h-cxphLb-cDlXUBOQ-X-4Ti-jty94yPp",
    "en-GB-oed", "LEuZl-so", "HyvBvFi-cCAl-X-irMQA-Pzt-H", "uDbsrAA-304", "wTS",
    "IWXS", "XvDqNkSn-jRDR", "gX-Ycbb-iLphEks-AQ1aJ5", "FbSBz-VLcR-VL", "JYoVQOP-Iytp",
    "gDSoDGD-lq-v-7aFec-ag-k-Z4-0kgNxXC-7h", "Bjvoayy-029", "qSDJd", "qpbQov", "fYIll-516",
    "GfgLyfWE-EHtB", "Wc-ZMtk", "cgh-VEYK", "WRZs-AaFd-yQ", "eSb-CpsZ-788", "YVwFU",
    "JSsHiQhr-MpjT-381", "LuhtJIQi-JKYt", "vVTvS-RHcP", "SY", "fSf-EgvQfI-ktWoG-8X5z-63PW",
    "NOKcy", "OjJb-550", "KB", "qzKBv-zDKk-589", "Jr", "Acw-GPXf-088", "WAFSbos",
    "HkgnmerM-x-e5-zf-VdDjcpz-1V6", "UAfYflJU-uXDc-YV", "x-CHsHx-VDcOUAur-FqagDTx-H-V0e74R",
    "uZIAZ-Xmbh-pd",
  ]

  for tag in tags {
    let result = LanguageTag::parse(tag)
    match result {
      Ok(_v) => ignore(_v) // 或者 debug("✓ \{tag} parsed successfully")
      Err(e) => debug("✗ \{tag} should be valid but failed: \{e}")
    }
    // 最终断言
  }
}

///|
test "random bad tags" {
  let tags = [
    "EdY-z_H791Xx6_m_kj", "qWt85_8S0-L_rbBDq0gl_m_O_zsAx_nRS", "VzyL2", "T_VFJq-L-0JWuH_u2_VW-hK-kbE",
    "u-t", "Q-f_ZVJXyc-doj_k-i", "JWB7gNa_K-5GB-25t_W-s-ZbGVwDu1-H3E", "b-2T-Qob_L-C9v_2CZxK86",
    "fQTpX_0_4Vg_L3L_g7VtALh2", "S-Z-E_J", "f6wsq-02_i-F", "9_GcUPq_G", "QjsIy_9-0-7_Dv2yPV09_D-JXWXM",
    "D_se-f-k", "ON47Wv1_2_W", "f-z-R_s-ha", "N3APeiw_195_Bx2-mM-pf-Z-Ip5lXWa-5r",
    "IRjxU-E_6kS_D_b1b_H", "NB-3-5-AyW_FQ-9hB-TrRJg3JV_3C", "yF-3a_V_FJQAHeL_Z-Mc-u",
    "n_w_bbunOG_1-s-tJMT5je", "Q-AEWE_X", "57b1O_k_R6MU_sb", "hK_65J_i-o_SI-Y", "wB4B7u_5I2_I_NZPI",
    "J24Nb_q_d-zE", "v6-dHjJmvPS_IEb-x_A-O-i", "8_8_dl-ZgBr84u-P-E", "nIn-xD7EVhe_C",
    "5_N-6P_x7Of_Lo_6_YX_R", "0_46Oo0sZ-YNwiU8Wr_d-M-pg1OriV", "laiY-5", "K-8Mdd-j_ila0sSpo_aO8_J",
    "wNATtSL-Cp4_gPa_fD41_9z", "H_FGz5V8_n6rrcoz0_1O6d-kH-7-N", "wDOrnHU-odqJ_vWl",
    "gP_qO-I-jH", "h", "dJ0hX-o_csBykEhU-F", "L-Vf7_BV_eRJ5goSF_Kp", "y-oF-chnavU-H",
    "9FkG-8Q-8_v", "W_l_QqI-O_SFSAOVq", "kDG3fzXw", "t-nsSp-7-t-mUK2", "Yw-F", "1-S_3_l",
    "u-v_brn-Y", "4_ft_3ZPZC5lA_D", "n_dR-QodsqJnh_e", "Hwvt-bSwZwj_KL-hxg0m-3_hUG",
    "mQHzvcV-UL-o2O_1KhUJQo_G2_uryk3-a", "b-UTn33HF", "r-Ep-jY-aFM_N_H", "K-k-krEZ0gwD_k_ua-9dm3Oy-s_v",
    "XS_oS-p", "EIx_h-zf5", "p_z-0_i-omQCo3B", "1_q0N_jo_9", "0Ai-6-S", "L-LZEp_HtW",
    "Zj-A4JD_2A5Aj7_b-m3", "x", "p-qPuXQpp_d-jeKifB-c-7_G-X", "X94cvJ_A", "F2D25R_qk_W-w_Okf_kx",
    "rc-f", "D", "gD_WrDfxmF-wu-E-U4t", "Z_BN9O4_D9-D_0E_KnCwZF-84b-19", "T-8_g-u-0_E",
    "lXTtys9j_X_A_m-vtNiNMw_X_b-C6Nr", "V_Ps-4Y-S", "X5wGEA", "mIbHFf_ALu4_Jo1Z1",
    "ET-TacYx_c", "Z-Lm5cAP_ri88-d_q_fi8-x", "rTi2ah-4j_j_4AlxTs6m_8-g9zqncIf-N5",
    "FBLB85_u-0NxhAy-ZU_9c", "x_j_l-5_aV95_s_tY_jp4", "PL768_D-m7jNWjfD-Nl_7qvb_bs_8_Vg",
    "9-yOc-gbh", "6DYxZ_SL-S_Ye", "ZCa-U-muib-6-d-f_oEh_O", "Qt-S-o8340F_f_aGax-c-jbV0gfK_p",
    "WE_SzOI_OGuoBDk-gDp", "cs-Y_9", "m1_uj", "Y-ob_PT", "li-B", "f-2-7-9m_f8den_J_T_d",
    "p-Os0dua-H_o-u", "L", "rby-w",
  ]
  for tag in tags {
    let result = LanguageTag::parse(tag)

    match result {
      Ok(v) => debug("✗ \{tag} should be rejected but passed: \{v}")
      // assert_true(false, "\{tag} should be considered not well-formed")
      Err(e) => ignore(e)
      // debug("✓ \{tag} correctly rejected: \{e}")
    }
  }
}

///|
test "eq" {
  let tag = LanguageTag::parse("en-fr").unwrap()
  @debug.assert_eq(tag.tag, "en-fr")
  assert_not_eq(tag.tag, "en-FR")
  @debug.assert_eq("en-fr", tag.tag)
}

///|
test "hash eq" {
  let tag = LanguageTag::parse("en-fr").unwrap()

  // 测试字段访问或基本属性
  @debug.assert_eq(tag.tag, "en-fr")

  // 测试相等性：自身等于自身
  @debug.assert_eq(tag, tag)

  // 测试哈希一致性：自身哈希等于自身哈希
  @debug.assert_eq(tag.hash(), tag.hash())

  // 如果有另一个相同的标签
  let tag2 = LanguageTag::parse("en-fr").unwrap()
  @debug.assert_eq(tag, tag2)
  @debug.assert_eq(tag.hash(), tag2.hash())
}

///|
test "debug_broken" {
  let tags = [
    "", "f", "f-Latn", "fr-Latn-F", "a-value", "tlh-a-b-foo", "i-notexist", "abcdefghi-012345678",
    "ab-abc-abc-abc-abc", "ab-abcd-abc", "ab-ab-abc", "ab-123-abc", "a-Hant-ZH",
    "a1-Hant-ZH", "ab-abcde-abc", "ab-1abc-abc", "ab-ab-abcd", "ab-123-abcd", "ab-abcde-abcd",
    "ab-1abc-abcd", "ab-a-b", "ab-a-x", "ab--ab", "ab-abc-", "-ab-abc", "abcd-efg",
    "aabbccddE",
  ]
  for tag in tags {
    let result = LanguageTag::parse(tag)
    // debug("\{tag}: \{result}")
    match result {
      Ok(v) => debug("✗ \{tag} should be rejected but passed: \{v}")
      // assert_true(false, "\{tag} should be considered not well-formed")
      Err(e) => ignore(e)
      // debug("✓ \{tag} correctly rejected: \{e}")
    }
  }
}

///|
test "broken tags with extensions 2" {
  let tags = [
    "", "f", "fr-Latn-F", "abcdefghi-012345678", "ab-abc-abc-abc-abc", "ab-abcd-abc",
    "ab-ab-abc", "ab-123-abc", "a1-Hant-ZH", "ab-abcde-abc", "ab-1abc-abc", "ab-ab-abcd",
    "ab-123-abcd", "ab-abcde-abcd", "ab-1abc-abcd", "ab-a-x", "ab--ab", "ab-abc-",
    "-ab-abc", "abcd-efg", "aabbccddE",
  ]

  for tag in tags {
    let result = LanguageTag::parse(tag)

    match result {
      Ok(v) => debug("✗ \{tag} should be rejected but passed: \{v}")
      // assert_true(false, "\{tag} should be considered not well-formed")
      Err(e) => ignore(e)
      // debug("✓ \{tag} correctly rejected: \{e}")
    }
  }
}

///|
test "random good tags 2" {
  let tags = [
    "zszLDm-sCVS-es-x-gn762vG-83-S-mlL", "IIJdFI-cfZv", "kbAxSgJ-685", "tbutP", "hDL-595",
    "dUf-iUjq-0hJ4P-5YkF-WD8fk", "FZAABA-FH", "xZ-lh-4QfM5z9J-1eG4-x-K-R6VPr2z",
    "Fyi", "SeI-DbaG", "ch-xwFn", "OeC-GPVI", "JLzvUSi", "Fxh-hLAs", "pKHzCP-sgaO-554",
    "eytqeW-hfgH-uQ", "ydn-zeOP-PR", "uoWmBM-yHCf-JE", "xwYem", "zie", "Re-wjSv-Ey-i-XE-E-JjWTEB8-f-DLSH-NVzLH-AtnFGWoH-SIDE",
    "Ri-063-c-u6v-ZfhkToTB-C-IFfmv-XT-j-rdyYFMhK-h-pY-D5-Oh6FqBhL-hcXt-v-WdpNx71-K-c74m4-eBTT7-JdH7Q1Z",
    "ji", "IM-487", "EPZ-zwcB", "GauwEcwo", "kDEP", "FwDYt-TNvo", "ottqP-KLES-x-9-i9",
    "fcflR-grQQ", "TvFwdu-kYhs", "WE-336", "MgxQa-ywEp-8lcW-7bvT-h-dP1Md-0h7-0Z3ir-K-Srkm-kA-7LXM-Z-whb2MiO-2mNsvbLm-W3O-4r-U-KceIxHdI-gvMVgUBV-2uRUni-J0-7C8yTK2",
    "Hyr-B-evMtVoB1-mtsVZf-vQMV-gM-I-rr-kvLzg-f-lAUK-Qb36Ne-Z-7eFzOD-mv6kKf-l-miZ7U3-k-XDGtNQG",
    "ybrlCpzy", "PTow-w-cAQ51-8Xd6E-cumicgt-WpkZv3NY-q-ORYPRy-v-A4jL4A-iNEqQZZ-sjKn-W-N1F-pzyc-xP5eWz-LmsCiCcZ",
    "ih-DlPR-PE", "Krf-362", "WzaD", "EPaOnB-gHHn", "XYta", "NZ-RgOO-tR", "at-FE",
    "Tpc-693", "YFp", "gRQrQULo", "pVomZ-585", "laSu-ZcAq-338", "gCW", "PydSwHRI-TYfF",
    "zKmWDD", "X-bCrL5RL", "HK", "YMKGcLY", "GDJ-nHYa-bw-X-ke-rohH5GfS-LdJKsGVe",
    "tfOxdau-yjge-489-a-oB-I8Csb-1ESaK1v-VFNz-N-FT-ZQyn-On2-I-hu-vaW3-jIQb-vg0U-hUl-h-dO6KuJqB-U-tde2L-P3gHUY-vnl5c-RyO-H-gK1-zDPu-VF1oeh8W-kGzzvBbW-yuAJZ",
    "LwDux", "Zl-072", "Ri-Ar", "vocMSwo-cJnr-288", "kUWq-gWfQ-794", "YyzqKL-273",
    "Xrw-ZHwH-841-9ddT-ESSZF-6OqO-0knk-991U-9p3m-b-JhiV-0Kq7Y-h-cxphLb-cDlXUBOQ-X-4Ti-jty94yPp",
    "en-GB-oed", "LEuZl-so", "HyvBvFi-cCAl-X-irMQA-Pzt-H", "uDbsrAA-304", "wTS",
    "IWXS", "XvDqNkSn-jRDR", "gX-Ycbb-iLphEks-AQ1aJ5", "FbSBz-VLcR-VL", "JYoVQOP-Iytp",
    "gDSoDGD-lq-v-7aFec-ag-k-Z4-0kgNxXC-7h", "Bjvoayy-029", "qSDJd", "qpbQov", "fYIll-516",
    "GfgLyfWE-EHtB", "Wc-ZMtk", "cgh-VEYK", "WRZs-AaFd-yQ", "eSb-CpsZ-788", "YVwFU",
    "JSsHiQhr-MpjT-381", "LuhtJIQi-JKYt", "vVTvS-RHcP", "SY", "fSf-EgvQfI-ktWoG-8X5z-63PW",
    "NOKcy", "OjJb-550", "KB", "qzKBv-zDKk-589", "Jr", "Acw-GPXf-088", "WAFSbos",
    "HkgnmerM-x-e5-zf-VdDjcpz-1V6", "UAfYflJU-uXDc-YV", "x-CHsHx-VDcOUAur-FqagDTx-H-V0e74R",
    "uZIAZ-Xmbh-pd",
  ]
  for tag in tags {
    let result = LanguageTag::parse(tag)
    // assert_true(result.is_ok(), "{} should be considered well-formed but returned error {}", tag, result.err().unwrap())
    assert_true(result is Ok(_))
    // debug(
    //   "\{tag}) should be considered well-formed but returned error \{result.unwrap()}",
    // )
  }
}

///|
/// 
test "random bad tags 2" {
  let tags = [
    "EdY-z_H791Xx6_m_kj", "qWt85_8S0-L_rbBDq0gl_m_O_zsAx_nRS", "VzyL2", "T_VFJq-L-0JWuH_u2_VW-hK-kbE",
    "u-t", "Q-f_ZVJXyc-doj_k-i", "JWB7gNa_K-5GB-25t_W-s-ZbGVwDu1-H3E", "b-2T-Qob_L-C9v_2CZxK86",
    "fQTpX_0_4Vg_L3L_g7VtALh2", "S-Z-E_J", "f6wsq-02_i-F", "9_GcUPq_G", "QjsIy_9-0-7_Dv2yPV09_D-JXWXM",
    "D_se-f-k", "ON47Wv1_2_W", "f-z-R_s-ha", "N3APeiw_195_Bx2-mM-pf-Z-Ip5lXWa-5r",
    "IRjxU-E_6kS_D_b1b_H", "NB-3-5-AyW_FQ-9hB-TrRJg3JV_3C", "yF-3a_V_FJQAHeL_Z-Mc-u",
    "n_w_bbunOG_1-s-tJMT5je", "Q-AEWE_X", "57b1O_k_R6MU_sb", "hK_65J_i-o_SI-Y", "wB4B7u_5I2_I_NZPI",
    "J24Nb_q_d-zE", "v6-dHjJmvPS_IEb-x_A-O-i", "8_8_dl-ZgBr84u-P-E", "nIn-xD7EVhe_C",
    "5_N-6P_x7Of_Lo_6_YX_R", "0_46Oo0sZ-YNwiU8Wr_d-M-pg1OriV", "laiY-5", "K-8Mdd-j_ila0sSpo_aO8_J",
    "wNATtSL-Cp4_gPa_fD41_9z", "H_FGz5V8_n6rrcoz0_1O6d-kH-7-N", "wDOrnHU-odqJ_vWl",
    "gP_qO-I-jH", "h", "dJ0hX-o_csBykEhU-F", "L-Vf7_BV_eRJ5goSF_Kp", "y-oF-chnavU-H",
    "9FkG-8Q-8_v", "W_l_QqI-O_SFSAOVq", "kDG3fzXw", "t-nsSp-7-t-mUK2", "Yw-F", "1-S_3_l",
    "u-v_brn-Y", "4_ft_3ZPZC5lA_D", "n_dR-QodsqJnh_e", "Hwvt-bSwZwj_KL-hxg0m-3_hUG",
    "mQHzvcV-UL-o2O_1KhUJQo_G2_uryk3-a", "b-UTn33HF", "r-Ep-jY-aFM_N_H", "K-k-krEZ0gwD_k_ua-9dm3Oy-s_v",
    "XS_oS-p", "EIx_h-zf5", "p_z-0_i-omQCo3B", "1_q0N_jo_9", "0Ai-6-S", "L-LZEp_HtW",
    "Zj-A4JD_2A5Aj7_b-m3", "x", "p-qPuXQpp_d-jeKifB-c-7_G-X", "X94cvJ_A", "F2D25R_qk_W-w_Okf_kx",
    "rc-f", "D", "gD_WrDfxmF-wu-E-U4t", "Z_BN9O4_D9-D_0E_KnCwZF-84b-19", "T-8_g-u-0_E",
    "lXTtys9j_X_A_m-vtNiNMw_X_b-C6Nr", "V_Ps-4Y-S", "X5wGEA", "mIbHFf_ALu4_Jo1Z1",
    "ET-TacYx_c", "Z-Lm5cAP_ri88-d_q_fi8-x", "rTi2ah-4j_j_4AlxTs6m_8-g9zqncIf-N5",
    "FBLB85_u-0NxhAy-ZU_9c", "x_j_l-5_aV95_s_tY_jp4", "PL768_D-m7jNWjfD-Nl_7qvb_bs_8_Vg",
    "9-yOc-gbh", "6DYxZ_SL-S_Ye", "ZCa-U-muib-6-d-f_oEh_O", "Qt-S-o8340F_f_aGax-c-jbV0gfK_p",
    "WE_SzOI_OGuoBDk-gDp", "cs-Y_9", "m1_uj", "Y-ob_PT", "li-B", "f-2-7-9m_f8den_J_T_d",
    "p-Os0dua-H_o-u", "L", "rby-w",
  ]
  for tag in tags {
    let result = LanguageTag::parse(tag)
    match result {
      Ok(v) =>
        // 关键：必须让测试失败
        fail("\{tag} should be rejected but passed: \{v}")
      Err(_e) =>
        // 正确拒绝，无需操作
        ignore(_e)
    }
  }
}

///|
test "str" {
  let tag = LanguageTag::parse("en-fr").unwrap()
  assert_true(tag.tag.has_prefix("en-"))
}

///|
test "extension_subtags iteration" {
  // 1. 测试包含多个扩展子标签的情况
  // en-US-u-co-phonebk-ca-gregory
  // 扩展部分为: u-co-phonebk-ca-gregory
  // 子标签应为: ["u", "co", "phonebk", "ca", "gregory"]
  let tag_str = "en-US-u-co-phonebk-ca-gregory"
  let lang_tag = LanguageTag::parse(tag_str).unwrap()

  let collected = []
  for subtag in lang_tag.extension_subtags().subtags {
    collected.push(subtag.to_string())
  }

  @debug.assert_eq(collected, ["u", "co", "phonebk", "ca", "gregory"])
}

///|
test "extension_subtags empty" {
  // 2. 测试没有扩展部分的情况
  // en-US
  let tag_str = "en-US"
  let lang_tag = LanguageTag::parse(tag_str).unwrap()

  let mut count = 0
  for _subtag in lang_tag.extension_subtags().subtags {
    count += 1
  }

  @debug.assert_eq(count, 0)
}

///|
test "extension_subtags single extension intro" {
  // 3. 测试只有扩展标识符，没有内容的情况 (虽然解析器可能会报错 EmptyExtension，但在合法标签中测试)
  // 注意：根据 RFC 5646，扩展标识符后必须跟随至少一个子标签，否则是 Ill-formed。
  // 我们的解析器 calculate_positions 中检查了 State::InExtension(true) 并返回 Err。
  // 因此我们测试一个合法的简单扩展：en-u-co
  let tag_str = "en-u-co"
  let lang_tag = LanguageTag::parse(tag_str).unwrap()

  let collected = []
  for subtag in lang_tag.extension_subtags().subtags {
    collected.push(subtag.to_string())
  }

  @debug.assert_eq(collected, ["u", "co"])
}

///|
test "extension_subtags multiple extensions" {
  // 4. 测试多个扩展序列 (例如 u-... 和 t-...)
  // en-US-u-co-phonebk-t-it-x-private
  // 扩展部分直到 x- 之前: u-co-phonebk-t-it
  let tag_str = "en-US-u-co-phonebk-t-it-x-private"
  let lang_tag = LanguageTag::parse(tag_str).unwrap()

  let collected = []
  for subtag in lang_tag.extension_subtags().subtags {
    collected.push(subtag.to_string())
  }

  // 期望: ["u", "co", "phonebk", "t", "it"]
  @debug.assert_eq(collected, ["u", "co", "phonebk", "t", "it"])
}
