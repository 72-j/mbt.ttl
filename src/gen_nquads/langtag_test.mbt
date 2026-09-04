///|
test "formatting" {
  @debug.assert_eq(
    "mn-Cyrl-MN",
    LanguageTag::parse_and_normalize("mn-Cyrl-MN").unwrap().to_tagstr(),
  )
  @debug.assert_eq(
    "mn-Cyrl-MN",
    LanguageTag::parse_and_normalize("MN-cYRL-mn").unwrap().to_tagstr(),
  )
  @debug.assert_eq(
    "mn-Cyrl-MN",
    LanguageTag::parse_and_normalize("mN-cYrL-Mn").unwrap().to_tagstr(),
  )

  @debug.assert_eq(
    "sgn-BE-FR",
    LanguageTag::parse_and_normalize("sgn-BE-FR").unwrap().to_tagstr(),
  )

  @debug.assert_eq(
    "i-ami",
    LanguageTag::parse_and_normalize("i-ami").unwrap().to_tagstr(),
  )
  @debug.assert_eq(
    "i-ami",
    LanguageTag::parse_and_normalize("I-AMI").unwrap().to_tagstr(),
  )
  @debug.assert_eq(
    "sl-afb-Latn-005-nedis",
    LanguageTag::parse_and_normalize("SL-AFB-lATN-005-nEdis")
    .unwrap()
    .to_tagstr(),
  )
}

///|
test "private use tag" {
  // 私有使用标签整体解析
  let tag = LanguageTag::parse("x-fr-CH").unwrap()
  assert_eq("x-fr-CH", tag.to_tagstr())
  assert_true(tag.private_use_subtags().contains("fr"))
  assert_true(tag.private_use_subtags().contains("CH"))
}

///|
test "primary language" {
  @debug.assert_eq(
    "fr",
    LanguageTag::parse_and_normalize("fr")
    .unwrap()
    .primary_language()
    .to_owned(),
  )
  @debug.assert_eq(
    "de",
    LanguageTag::parse_and_normalize("de")
    .unwrap()
    .primary_language()
    .to_owned(),
  )
  @debug.assert_eq(
    "x-fr-ch",
    LanguageTag::parse_and_normalize("x-fr-CH")
    .unwrap()
    .primary_language()
    .to_owned(),
  )
  @debug.assert_eq(
    "i-klingon",
    LanguageTag::parse_and_normalize("i-klingon")
    .unwrap()
    .primary_language()
    .to_owned(),
  )
  @debug.assert_eq(
    "i-bnn",
    LanguageTag::parse_and_normalize("i-bnn")
    .unwrap()
    .primary_language()
    .to_owned(),
  )
  @debug.assert_eq(
    "zh-hakka",
    LanguageTag::parse_and_normalize("zh-hakka")
    .unwrap()
    .primary_language()
    .to_owned(),
  )
}

///|
test "extended language" {
  let tag_zh = LanguageTag::parse("zh").unwrap()
  @debug.assert_eq("zh", tag_zh.full_language().to_owned())
  @debug.assert_eq("zh", tag_zh.primary_language().to_owned())
  @debug.assert_eq(None, tag_zh.extended_language())

  @debug.assert_eq([], tag_zh.extended_language_subtags())

  let tag_zh_gan = LanguageTag::parse("zh-gan").unwrap()
  @debug.assert_eq("zh-gan", tag_zh_gan.full_language().to_owned())
  @debug.assert_eq("zh", tag_zh_gan.primary_language().to_owned())
  @debug.assert_eq(Some("gan"[:]), tag_zh_gan.extended_language())
  @debug.assert_eq(["gan"[:]], tag_zh_gan.extended_language_subtags())

  let tag_zh_gan_foo = LanguageTag::parse("zh-gan-foo").unwrap()
  @debug.assert_eq("zh-gan-foo"[:], tag_zh_gan_foo.full_language().to_owned())
  @debug.assert_eq("zh", tag_zh_gan_foo.primary_language().to_owned())
  @debug.assert_eq(Some("gan-foo"[:]), tag_zh_gan_foo.extended_language())
  @debug.assert_eq(
    ["gan"[:], "foo"],
    tag_zh_gan_foo.extended_language_subtags(),
  )

  let tag_zh_min_nan = LanguageTag::parse("zh-min-nan").unwrap()
  @debug.assert_eq("zh-min-nan"[:], tag_zh_min_nan.full_language().to_owned())
  @debug.assert_eq("zh-min-nan", tag_zh_min_nan.primary_language().to_owned())
  @debug.assert_eq(None, tag_zh_min_nan.extended_language())

  @debug.assert_eq(0, tag_zh_min_nan.extended_language_subtags().length())

  let tag_i_tsu = LanguageTag::parse("i-tsu").unwrap()
  @debug.assert_eq("i-tsu", tag_i_tsu.full_language().to_owned())
  @debug.assert_eq("i-tsu", tag_i_tsu.primary_language().to_owned())
  @debug.assert_eq(None, tag_i_tsu.extended_language())

  @debug.assert_eq(0, tag_i_tsu.extended_language_subtags().length())

  let tag_zh_cn = LanguageTag::parse("zh-CN").unwrap()
  @debug.assert_eq("zh", tag_zh_cn.full_language().to_owned())
  @debug.assert_eq("zh", tag_zh_cn.primary_language().to_owned())
  @debug.assert_eq(None, tag_zh_cn.extended_language())

  @debug.assert_eq(0, tag_zh_cn.extended_language_subtags().length())

  let tag_zh_gan_cn = LanguageTag::parse("zh-gan-CN").unwrap()
  @debug.assert_eq("zh-gan", tag_zh_gan_cn.full_language().to_owned())
  @debug.assert_eq("zh", tag_zh_gan_cn.primary_language().to_owned())
  @debug.assert_eq(Some("gan"[:]), tag_zh_gan_cn.extended_language())
  @debug.assert_eq(["gan"[:]], tag_zh_gan_cn.extended_language_subtags())

  let tag_ar_afb = LanguageTag::parse("ar-afb").unwrap()
  @debug.assert_eq("ar-afb", tag_ar_afb.full_language().to_owned())
  @debug.assert_eq("ar", tag_ar_afb.primary_language().to_owned())
  match tag_ar_afb.extended_language() {
    Some(ext) => @debug.assert_eq(ext, "afb")
    None => fail("Expected extended language 'afb', got None")
  }
  @debug.assert_eq(["afb"[:]], tag_ar_afb.extended_language_subtags())
  @debug.assert_eq(["afb"[:]], tag_ar_afb.extended_language_subtags())
}

///|
test "script" {
  @debug.assert_eq(
    Some("Latn"[:]),
    LanguageTag::parse("sr-Latn").unwrap().script(),
  )
  @debug.assert_eq(
    Some("Latn"[:]),
    LanguageTag::parse("ar-afb-Latn").unwrap().script(),
  )
}

///|
test "region" {
  @debug.assert_eq(Some("AT"[:]), LanguageTag::parse("de-AT").unwrap().region())
  @debug.assert_eq(
    Some("RS"[:]),
    LanguageTag::parse("sr-Latn-RS").unwrap().region(),
  )
  @debug.assert_eq(
    Some("419"[:]),
    LanguageTag::parse("es-419").unwrap().region(),
  )
  @debug.assert_eq(Some("DE"[:]), LanguageTag::parse("ar-DE").unwrap().region())
  @debug.assert_eq(
    Some("005"[:]),
    LanguageTag::parse("ar-005").unwrap().region(),
  )
}

///|
test "variant" {
  @debug.assert_eq([], LanguageTag::parse("sl").unwrap().variant_subtags())
  @debug.assert_eq(
    ["nedis"[:]],
    LanguageTag::parse("sl-nedis").unwrap().variant_subtags(),
  )
  @debug.assert_eq(
    ["1996"[:]],
    LanguageTag::parse("de-CH-1996").unwrap().variant_subtags(),
  )
  @debug.assert_eq(
    [],
    LanguageTag::parse("art-lojban").unwrap().variant_subtags(),
  )
}

///|
test "extended_language" {
  // 无扩展语言
  @debug.assert_eq(None, LanguageTag::parse("en").unwrap().extended_language())

  // 标准扩展语言（3位字母）
  let tag_zh_gan = LanguageTag::parse("zh-gan").unwrap()
  @debug.assert_eq(Some("gan"[:]), tag_zh_gan.extended_language())

  // 多个扩展语言
  let tag_cmn = LanguageTag::parse("zh-cmn-hans").unwrap()
  @debug.assert_eq(Some("cmn"[:]), tag_cmn.extended_language())

  // script 是 "Hans"
  @debug.assert_eq(Some("hans"[:]), tag_cmn.script())

  // 祖父标签无扩展语言
  @debug.assert_eq(
    None,
    LanguageTag::parse("i-tsu").unwrap().extended_language(),
  )
}

///|
test "extended_language_subtags" {
  // 单一扩展语言
  let tag_zh_gan = LanguageTag::parse("zh-gan").unwrap()
  @debug.assert_eq(["gan"[:]], tag_zh_gan.extended_language_subtags())

  // 多个扩展语言（多个3位字母）
  let tag_cmn_yue = LanguageTag::parse("zh-cmn-yue").unwrap()
  @debug.assert_eq(
    ["cmn"[:], "yue"[:]],
    tag_cmn_yue.extended_language_subtags(),
  )

  // 扩展语言 + 脚本（Hans 是脚本，不是 extlang）
  let tag_script = LanguageTag::parse("zh-cmn-hans").unwrap()
  @debug.assert_eq(["cmn"[:]], tag_script.extended_language_subtags())
  @debug.assert_eq(Some("hans"[:]), tag_script.script())
}

///|
test "full_language" {
  let tag_zh_gan = LanguageTag::parse("zh-gan").unwrap()
  @debug.assert_eq("zh-gan"[:], tag_zh_gan.full_language().to_owned())
  @debug.assert_eq("zh"[:], tag_zh_gan.primary_language().to_owned())
}

///|
test "private_use" {
  let tag = LanguageTag::parse("en-x-US").unwrap()
  @debug.assert_eq(["US"[:]], tag.private_use_subtags())

  let tag_multi = LanguageTag::parse("x-fr-CH-Private").unwrap()
  @debug.assert_eq(
    ["fr"[:], "CH"[:], "Private"[:]],
    tag_multi.private_use_subtags(),
  )
}

///|
test "has_private_use" {
  let tag1 = LanguageTag::parse("en").unwrap()
  @debug.assert_eq(false, tag1.has_private_use())

  let tag2 = LanguageTag::parse("en-x-US").unwrap()
  @debug.assert_eq(true, tag2.has_private_use())
}

///|
test "private_use_first_subtag" {
  // 获取第一个私有使用子标签
  let tag1 = LanguageTag::parse("en-x-US").unwrap()
  @debug.assert_eq(Some("US"[:]), tag1.private_use_subtags().get(0))

  let tag2 = LanguageTag::parse("x-fr-ch").unwrap()
  @debug.assert_eq(Some("fr"[:]), tag2.private_use_subtags().get(0))

  let tag3 = LanguageTag::parse("es-x-foobar-AT-007").unwrap()
  @debug.assert_eq(Some("foobar"[:]), tag3.private_use_subtags().get(0))
}

///|
test "privateuse" {
  @debug.assert_eq(
    None,
    LanguageTag::parse("en").unwrap().private_use_subtags().get(0),
  )

  @debug.assert_eq(
    ["foobar"[:], "AT"[:], "007"[:]],
    LanguageTag::parse("es-x-foobar-AT-007").unwrap().private_use_subtags(),
  )
}

///|
test "fmt" {
  @debug.assert_eq(
    "ar-arb-Latn-DE-nedis-foobar",
    LanguageTag::parse_and_normalize("ar-arb-latn-de-nedis-foobar")
    .unwrap()
    .to_tagstr(),
  )
  @debug.assert_eq(
    "ar-arb-Latn-DE-nedis-foobar",
    LanguageTag::parse_and_normalize("AR-ARB-LATN-DE-NEDIS-FOOBAR")
    .unwrap()
    .to_tagstr(),
  )
  @debug.assert_eq(
    "xx-z-foo-a-bar-f-spam-b-eggs",
    LanguageTag::parse_and_normalize("xx-z-foo-a-bar-F-spam-b-eggs")
    .unwrap()
    .to_tagstr(),
  )
  @debug.assert_eq(
    "hkgnmerm-x-e5-zf-vddjcpz-1v6",
    LanguageTag::parse_and_normalize("HkgnmerM-x-e5-zf-VdDjcpz-1V6")
    .unwrap()
    .to_tagstr(),
  )
  @debug.assert_eq(
    "mgxqa-Ywep-8lcw-7bvt-h-dp1md-0h7-0z3ir",
    LanguageTag::parse_and_normalize("MgxQa-ywEp-8lcW-7bvT-h-dP1Md-0h7-0Z3ir")
    .unwrap()
    .to_tagstr(),
  )
}

///|
test "unicode" {
  assert_false(LanguageTag::parse("zh-x-Üńìcødê") is Ok(_))
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
    "ab-x-abc-a-a", "i-default", "i-klingon", "AaBbCcDd-x-y-any-x", "en", "de-AT",
    "es-419", "de-CH-1901", "sr-Cyrl", "sr-Cyrl-CS", "sl-Latn-IT-rozaj", "en-US-x-twain",
    "zh-cmn", "zh-cmn-Hant", "zh-cmn-Hant-HK", "zh-gan", "zh-yue-Hant-HK", "xr-lxs-qut",
    "xr-lqt-qu", "xr-p-lze",
  ]
  for tag in tags {
    let result = LanguageTag::parse(tag)
    match result {
      Ok(_v) => ()
      Err(e) => fail("✗ \{tag} should be accepted: \{e}")
    }
  }
}

///|
test "invalid language length" {
  // 4 位主语言是无效的
  let result1 = LanguageTag::parse("abcd-efg")
  assert_true(result1 is Err(_))

  // 有效长度
  let result2 = LanguageTag::parse("ab-efg")
  assert_true(result2 is Ok(_))

  // 5 位主语言本身有效
  let result3 = LanguageTag::parse("abcde")
  assert_true(result3 is Ok(_))

  // 5 位主语言后不允许 extlang，"efg" 也不是合法 script/region/variant → 整体非法
  let result4 = LanguageTag::parse("abcde-efg")
  assert_true(result4 is Err(_))
}

///|
test "eq" {
  let tag = LanguageTag::parse("en-fr").unwrap()
  @debug.assert_eq(tag.tag, "en-fr")
  assert_not_eq(tag.tag, "en-FR")
  @debug.assert_eq("en-fr", tag.tag.to_owned())
}

///|
test "hash eq" {
  let tag = LanguageTag::parse("en-fr").unwrap()

  @debug.assert_eq(tag.tag, "en-fr")

  @debug.assert_eq(tag, tag)

  // @debug.assert_eq(tag.hash(), tag.hash())

  let tag2 = LanguageTag::parse("en-fr").unwrap()
  @debug.assert_eq(tag, tag2)
  // @debug.assert_eq(tag.hash(), tag2.hash())
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
      Ok(v) => fail("\{tag} should be rejected but passed: \{v}")
      Err(_e) => ignore(_e)
    }
  }
}

///|
test "extension_subtags iteration" {
  let tag_str = "en-US-u-co-phonebk-ca-gregory"
  let lang_tag = LanguageTag::parse(tag_str).unwrap()

  let exts = lang_tag.extension_subtags().to_array()
  let collected : Array[String] = []
  for ext in exts {
    collected.push(ext.0.to_owned())
    for sub in ext.1 {
      collected.push(sub.to_owned())
    }
  }

  @debug.assert_eq(collected[:], ["u", "co", "phonebk", "ca", "gregory"])
}

///|
test "extension_subtags single extended_language intro" {
  let tag_str = "en-u-co"
  let lang_tag = LanguageTag::parse(tag_str).unwrap()
  let mut count = 0
  for _subtag in lang_tag.extension_subtags().extensions {
    count += 1
  }

  @debug.assert_eq(count, 1)
}

// ============================================================
// 桶测试总纲：按类别归类（对齐非法标签规则清单），全部真实断言
// 之前重复的 debug_broken / broken tags / broken tags with extended_language /
// random good tags 2 / parse_tag buckets 已合并至此
// ============================================================

///|
test "langtag buckets" {
  // ---------- 通过桶：祖父标签（大小写不敏感） ----------
  let passed_grandfathered = [
    "en-GB-oed", "art-lojban", "cel-gaulish", "i-ami", "i-klingon", "I-kLINgon",
    "i-enochian", "i-tsu", "no-bok", "no-nyn", "sgn-BE-FR", "sgn-CH-DE", "zh-guoyu",
    "zh-hakka", "zh-min", "zh-min-nan", "zh-xiang", "i-default",
  ]
  // ---------- 通过桶：良构标签（按成分分组） ----------
  let passed = [
    // 纯语言（2-3 位 / 5-8 位）
    "fr", "ji", "KB", "SY", "tbutP", "xwYem", "GauwEcwo", "ybrlCpzy",
    // 语言 + script（4 位字母）
     "fr-Latn", "sr-Cyrl", "sr-Latn-CS", "ch-xwFn", "Fxh-hLAs", "mn-Cyrl-MN", "mN-cYrL-Mn",
    // 语言 + region（2 字母 / 3 数字）
     "de-AT", "en-US", "fr-Latn-FR", "ax-TZ", "es-419", "Tpc-693", "WE-336",
    // 语言 + variant（5-8 位字母数字 / 数字开头 4 位）
     "fr-shadok", "sl-nedis", "de-CH-1996", "de-CH-1901", "de-Latg-1996", "en-US-boont",
    "gX-Ycbb-iLphEks-AQ1aJ5",
    // extlang（2-3 位语言后最多 3 个 3 位字母；后随 script/region 合法）
     "fr-fra", "fra", "fr-Lat", "zh-gan", "zh-cmn", "zh-cmn-Hant", "zh-cmn-Hant-HK",
    "zh-gan-CN", "zh-yue-Hant-HK", "xr-lxs-qut", "xr-lqt-qu", "ar-afb-Latn", "sl-afb-Latn-005-nedis",
    "sl-Latn-IT-rozaj",
    // extension（单字符标识符 + 1-8 位子标签，可多个）
     "fr-y-myext-myext2", "de-a-value", "en-a-bbb-x-a-ccc", "xr-p-lze", "en-Latn-GB-boont-r-extended-sequence-x-private",
    "Re-wjSv-Ey-i-XE-E-JjWTEB8-f-DLSH-NVzLH-AtnFGWoH-SIDE",
    // privateuse（x- 整条 / 混合尾部；singleton 大小写不敏感）
     "x-fr-CH", "X-bCrL5RL", "en-x-US", "en-US-x-twain", "es-Latn-CO-x-private",
    "az-Arab-x-AZE-derbend", "ab-x-abc-x-abc", "ab-x-abc-a-a", "AaBbCcDd-x-y-any-x",
    "x-CHsHx-VDcOUAur-FqagDTx-H-V0e74R",
    // 混合
     "fra-Latn", "fra-FX", "sl-IT-nedis", "zh-min-nan",
  ]

  // ---------- 拒绝桶（对齐非法标签规则清单） ----------
  // 1. 空标签
  let bad_empty = [""]
  // 2. 语言子标签错误：单字母 / 4 字母主语言 / 超长 / 未注册 i- 前缀 / 5-8 位语言后悬挂
  let bad_language = [
    "f", "f-Latn", "a-value", "abcd-efg", "aabbccddE", "abcdefghi-012345678", "i-notexist",
    "tlh-a-b-foo", "abcde-efg", "u-t", "x", "h", "L", "D", "b-UTn33HF", "t-nsSp-7-t-mUK2",
    "y-oF-chnavU-H", "9-yOc-gbh", "laiY-5",
  ]
  // 2b. 4 字母主语言（fuzzer 误标 good 的样本，规则同 "abcd-efg"）
  let bad_language_4letter = [
    "IWXS", "kDEP", "WzaD", "XYta", "OjJb-550", "WRZs-AaFd-yQ", "laSu-ZcAq-338",
    "kUWq-gWfQ-794", "PTow-w-cAQ51-8Xd6E-cumicgt-WpkZv3NY-q-ORYPRy-v-A4jL4A-iNEqQZZ-sjKn-W-N1F-pzyc-xP5eWz-LmsCiCcZ",
  ]
  // 3. 次级子标签错误：region 单字母 / 非法 variant / extension 单标识符无子标签
  let bad_secondary = [
    "fr-Latn-F", "ab-abcd-abc", "ab-1abc-abc", "ab-a-b", "ab-a-x", "ab-abcde-abc",
    "ab-abcde-abcd", "ab-1abc-abcd", "rc-f", "li-B", "Yw-F", "rby-w",
  ]
  // 4. 连字符位置 / 成分顺序错误
  let bad_hyphen = [
    "ab--ab", "ab-abc-", "-ab-abc", "ab-123-abc", "ab-123-abcd", "ab-ab-abc", "ab-ab-abcd",
  ]
  // 5. 子标签数量超限（extlang 最多 3 个，超出的悬挂）
  let bad_count = ["ab-abc-abc-abc-abc"]
  // 6. 字符格式错误：数字开头语言
  let bad_char = ["a1-Hant-ZH", "a-Hant-ZH", "VzyL2", "X5wGEA", "0Ai-6-S"]

  for tag in passed_grandfathered {
    match LanguageTag::parse(tag) {
      Err(e) => fail("grandfathered bucket rejected: \{tag}: \{e}")
      Ok(_v) => ()
    }
  }
  for tag in passed {
    match LanguageTag::parse(tag) {
      Err(e) => fail("passed bucket rejected valid tag: \{tag}: \{e}")
      Ok(_v) => ()
    }
  }
  let bads : Array[(String, Array[String])] = [
    ("empty", bad_empty),
    ("language", bad_language),
    ("language_4letter", bad_language_4letter),
    ("secondary", bad_secondary),
    ("hyphen", bad_hyphen),
    ("count", bad_count),
    ("char", bad_char),
  ]
  for bucket in bads {
    let (name, tags) = bucket
    for tag in tags {
      match LanguageTag::parse(tag) {
        Ok(v) => fail("bad[\{name}] accepted invalid tag: \{tag}: \{v}")
        Err(_e) => ()
      }
    }
  }
}

///|
test "random good tags" {
  // fuzzer 良构集（断言全部必须通过）
  // 注：4 字母主语言的误标样本（IWXS/kDEP/WzaD 等）已移入 "langtag buckets" 的
  // bad_language_4letter 桶
  let tags = [
    "zszLDm-sCVS-es-x-gn762vG-83-S-mlL", "IIJdFI-cfZv", "kbAxSgJ-685", "tbutP", "hDL-595",
    "dUf-iUjq-0hJ4P-5YkF-WD8fk", "FZAABA-FH", "xZ-lh-4QfM5z9J-1eG4-x-K-R6VPr2z",
    "Fyi", "SeI-DbaG", "ch-xwFn", "OeC-GPVI", "JLzvUSi", "Fxh-hLAs", "pKHzCP-sgaO-554",
    "eytqeW-hfgH-uQ", "ydn-zeOP-PR", "uoWmBM-yHCf-JE", "xwYem", "zie", "Re-wjSv-Ey-i-XE-E-JjWTEB8-f-DLSH-NVzLH-AtnFGWoH-SIDE",
    "Ri-063-c-u6v-ZfhkToTB-C-IFfmv-XT-j-rdyYFMhK-h-pY-D5-Oh6FqBhL-hcXt-v-WdpNx71-K-c74m4-eBTT7-JdH7Q1Z",
    "ji", "IM-487", "EPZ-zwcB", "GauwEcwo", "FwDYt-TNvo", "ottqP-KLES-x-9-i9", "fcflR-grQQ",
    "TvFwdu-kYhs", "WE-336", "MgxQa-ywEp-8lcW-7bvT-h-dP1Md-0h7-0Z3ir-K-Srkm-kA-7LXM-Z-whb2MiO-2mNsvbLm-W3O-4r-U-KceIxHdI-gvMVgUBV-2uRUni-J0-7C8yTK2",
    "Hyr-B-evMtVoB1-mtsVZf-vQMV-gM-I-rr-kvLzg-f-lAUK-Qb36Ne-Z-7eFzOD-mv6kKf-l-miZ7U3-k-XDGtNQG",
    "ybrlCpzy", "ih-DlPR-PE", "Krf-362", "EPaOnB-gHHn", "NZ-RgOO-tR", "at-FE", "Tpc-693",
    "YFp", "gRQrQULo", "pVomZ-585", "gCW", "PydSwHRI-TYfF", "zKmWDD", "X-bCrL5RL",
    "HK", "YMKGcLY", "GDJ-nHYa-bw-X-ke-rohH5GfS-LdJKsGVe", "tfOxdau-yjge-489-a-oB-I8Csb-1ESaK1v-VFNz-N-FT-ZQyn-On2-I-hu-vaW3-jIQb-vg0U-hUl-h-dO6KuJqB-U-tde2L-P3gHUY-vnl5c-RyO-H-gK1-zDPu-VF1oeh8W-kGzzvBbW-yuAJZ",
    "LwDux", "Zl-072", "Ri-Ar", "vocMSwo-cJnr-288", "YyzqKL-273", "Xrw-ZHwH-841-9ddT-ESSZF-6OqO-0knk-991U-9p3m-b-JhiV-0Kq7Y-h-cxphLb-cDlXUBOQ-X-4Ti-jty94yPp",
    "en-GB-oed", "LEuZl-so", "HyvBvFi-cCAl-X-irMQA-Pzt-H", "uDbsrAA-304", "wTS",
    "XvDqNkSn-jRDR", "gX-Ycbb-iLphEks-AQ1aJ5", "FbSBz-VLcR-VL", "JYoVQOP-Iytp", "gDSoDGD-lq-v-7aFec-ag-k-Z4-0kgNxXC-7h",
    "Bjvoayy-029", "qSDJd", "qpbQov", "fYIll-516", "GfgLyfWE-EHtB", "Wc-ZMtk", "cgh-VEYK",
    "eSb-CpsZ-788", "YVwFU", "JSsHiQhr-MpjT-381", "LuhtJIQi-JKYt", "vVTvS-RHcP",
    "SY", "fSf-EgvQfI-ktWoG-8X5z-63PW", "NOKcy", "KB", "qzKBv-zDKk-589", "Jr", "Acw-GPXf-088",
    "WAFSbos", "HkgnmerM-x-e5-zf-VdDjcpz-1V6", "UAfYflJU-uXDc-YV", "x-CHsHx-VDcOUAur-FqagDTx-H-V0e74R",
    "uZIAZ-Xmbh-pd",
  ]
  for tag in tags {
    match LanguageTag::parse(tag) {
      Ok(_v) => ()
      Err(e) => fail("\{tag} should be valid but failed: \{e}")
    }
  }
}
