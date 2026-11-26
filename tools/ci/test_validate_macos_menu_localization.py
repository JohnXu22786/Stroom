import unittest

from validate_macos_menu_localization import has_localization_build_membership


VALID_PROJECT = """
/* Begin PBXProject section */
\t\t900000000000000000000001 = {
\t\t\tisa = PBXProject;
\t\t\tmainGroup = 100000000000000000000001;
\t\t\ttargets = (C00000000000000000000001, );
\t\t};
/* End PBXProject section */
/* Begin PBXBuildFile section */
\t\tB00000000000000000000001 = {
\t\t\tisa = PBXBuildFile; fileRef = A00000000000000000000001;
\t\t};
/* End PBXBuildFile section */
/* Begin PBXFileReference section */
\t\tE00000000000000000000001 = {
\t\t\tisa = PBXFileReference; name = en; path = en.lproj/MainMenu.strings; sourceTree = \"<group>\";
\t\t};
\t\tD00000000000000000000001 = {
\t\t\tisa = PBXFileReference; name = \"zh-Hans\"; path = \"zh-Hans.lproj/MainMenu.strings\"; sourceTree = \"<group>\";
\t\t};
/* End PBXFileReference section */
/* Begin PBXGroup section */
\t\t100000000000000000000001 = {
\t\t\tisa = PBXGroup; children = (200000000000000000000001, ); sourceTree = \"<group>\";
\t\t};
\t\t200000000000000000000001 = {
\t\t\tisa = PBXGroup; children = (300000000000000000000001, ); path = Runner; sourceTree = \"<group>\";
\t\t};
\t\t300000000000000000000001 = {
\t\t\tisa = PBXGroup; children = (A00000000000000000000001, ); path = ..; sourceTree = \"<group>\";
\t\t};
/* End PBXGroup section */
/* Begin PBXNativeTarget section */
\t\tC00000000000000000000001 = {
\t\t\tisa = PBXNativeTarget; buildPhases = (F00000000000000000000001, ); name = Runner;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */
/* Begin PBXResourcesBuildPhase section */
\t\tF00000000000000000000001 = {
\t\t\tisa = PBXResourcesBuildPhase; files = (B00000000000000000000001, );
\t\t};
/* End PBXResourcesBuildPhase section */
/* Begin PBXVariantGroup section */
\t\tA00000000000000000000001 = {
\t\t\tisa = PBXVariantGroup; children = (E00000000000000000000001, D00000000000000000000001, ); path = Runner; sourceTree = \"<group>\";
\t\t};
/* End PBXVariantGroup section */
rootObject = 900000000000000000000001;
"""


class ValidateMacosMenuLocalizationTest(unittest.TestCase):
    localized_paths = {
        "en": "en.lproj/MainMenu.strings",
        "zh-Hans": "zh-Hans.lproj/MainMenu.strings",
    }

    def test_accepts_localized_resources_in_runner_resources_variant_group(self):
        self.assertTrue(
            has_localization_build_membership(VALID_PROJECT, self.localized_paths)
        )

    def test_rejects_standalone_localized_file_references_outside_build_membership(self):
        project = VALID_PROJECT.replace(
            "/* Begin PBXVariantGroup section */"
            "\n\t\tA00000000000000000000001 = {"
            "\n\t\t\tisa = PBXVariantGroup; children = (E00000000000000000000001, D00000000000000000000001, ); path = Runner; sourceTree = \"<group>\";"
            "\n\t\t};\n/* End PBXVariantGroup section */",
            "/* Begin PBXVariantGroup section */\n/* End PBXVariantGroup section */",
        )

        self.assertFalse(
            has_localization_build_membership(project, self.localized_paths)
        )

    def test_rejects_orphan_runner_target_with_localization_resources(self):
        project = VALID_PROJECT.replace(
            "buildPhases = (F00000000000000000000001, ); name = Runner;",
            "buildPhases = (); name = Runner;",
        ).replace(
            "/* End PBXNativeTarget section */",
            """
\t\tD00000000000000000000001 = {
\t\t\tisa = PBXNativeTarget; buildPhases = (F00000000000000000000001, ); name = Runner;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */""",
        )

        self.assertFalse(
            has_localization_build_membership(project, self.localized_paths)
        )

    def test_ignores_targets_from_unreferenced_project_objects(self):
        project = VALID_PROJECT.replace(
            "/* End PBXVariantGroup section */",
            """/* End PBXVariantGroup section */
\t\t800000000000000000000001 = {
\t\t\tisa = PBXProject; targets = (D00000000000000000000001, );
\t\t};""",
        ).replace(
            "buildPhases = (F00000000000000000000001, ); name = Runner;",
            "buildPhases = (); name = Runner;",
        ).replace(
            "/* End PBXNativeTarget section */",
            """
\t\tD00000000000000000000001 = {
\t\t\tisa = PBXNativeTarget; buildPhases = (F00000000000000000000001, ); name = Runner;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */""",
        )

        self.assertFalse(
            has_localization_build_membership(project, self.localized_paths)
        )

    def test_rejects_non_application_runner_target(self):
        project = VALID_PROJECT.replace(
            'productType = "com.apple.product-type.application";',
            'productType = "com.apple.product-type.bundle.unit-test";',
        )

        self.assertFalse(
            has_localization_build_membership(project, self.localized_paths)
        )

    def test_rejects_localized_references_resolved_from_source_root(self):
        project = VALID_PROJECT.replace(
            "path = en.lproj/MainMenu.strings; sourceTree = \"<group>\";",
            "path = en.lproj/MainMenu.strings; sourceTree = SOURCE_ROOT;",
        ).replace(
            "path = \"zh-Hans.lproj/MainMenu.strings\"; sourceTree = \"<group>\";",
            "path = \"zh-Hans.lproj/MainMenu.strings\"; sourceTree = SOURCE_ROOT;",
        )

        self.assertFalse(
            has_localization_build_membership(project, self.localized_paths)
        )

    def test_rejects_object_ids_present_only_in_project_comments(self):
        decoy_build_file = VALID_PROJECT.replace(
            "files = (B00000000000000000000001, );",
            "files = (/* B00000000000000000000001 */);",
        )
        decoy_variant_children = VALID_PROJECT.replace(
            "children = (E00000000000000000000001, D00000000000000000000001, );",
            "children = (/* E00000000000000000000001 */ /* D00000000000000000000001 */);",
        )

        for project in (decoy_build_file, decoy_variant_children):
            with self.subTest(project=project):
                self.assertFalse(
                    has_localization_build_membership(project, self.localized_paths)
                )

    def test_ignores_group_paths_that_appear_only_in_comments(self):
        project = VALID_PROJECT.replace(
            'path = Runner; sourceTree = "<group>";',
            '/* path = Runner; */ path = Other; sourceTree = "<group>";',
        )

        self.assertFalse(
            has_localization_build_membership(project, self.localized_paths)
        )

    def test_ignores_array_fields_that_appear_only_in_comments(self):
        project = VALID_PROJECT.replace(
            "files = (B00000000000000000000001, );",
            "/* files = (B00000000000000000000001, ); */ files = ();",
        )

        self.assertFalse(
            has_localization_build_membership(project, self.localized_paths)
        )

    def test_ignores_project_objects_that_appear_only_in_comments(self):
        project = VALID_PROJECT.replace(
            "/* Begin PBXVariantGroup section */",
            "/* Begin PBXVariantGroup section */\n/*",
        ).replace(
            "/* End PBXVariantGroup section */",
            "*/\n/* End PBXVariantGroup section */",
        )

        self.assertFalse(
            has_localization_build_membership(project, self.localized_paths)
        )


if __name__ == "__main__":
    unittest.main()
