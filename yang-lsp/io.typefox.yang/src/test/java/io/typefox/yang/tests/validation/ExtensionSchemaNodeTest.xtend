package io.typefox.yang.tests.validation

import io.typefox.yang.tests.AbstractYangTest
import io.typefox.yang.validation.IssueCodes
import java.io.File
import org.eclipse.xtext.workspace.FileProjectConfig
import org.eclipse.xtext.workspace.ProjectConfigAdapter
import org.junit.Assert
import org.junit.Test

/**
 * Extensions mapped through 'extensionSchemaNodes' (e.g. NSO's tailf:action) define
 * action schema nodes: their input/output must not collide with sibling actions, and
 * refine statements must be able to target them, including through groupings.
 */
class ExtensionSchemaNodeTest extends AbstractYangTest {

	static val EXTENSION_MODULE = '''
		module ext {
			yang-version 1.1;
			namespace urn:ext;
			prefix e;
			extension action {
				argument name;
			}
		}
	'''

	static val USING_MODULE = '''
		module foo {
			yang-version 1.1;
			namespace urn:foo;
			prefix f;
			import ext {
				prefix x;
			}
			grouping result {
				leaf success {
					type boolean;
				}
			}
			grouping actions {
				x:action "status" {
					input {
						leaf verbose {
							type boolean;
						}
					}
					output {
						uses result;
					}
				}
			}
			container c {
				x:action "deploy" {
					output {
						uses result;
					}
				}
				x:action "remove" {
					output {
						uses result;
					}
				}
				uses actions {
					refine "status" {
						description "Refined extension action.";
					}
					refine "status/input/verbose" {
						description "Refined leaf inside an extension action.";
					}
				}
			}
			augment "/f:c/f:deploy/f:output" {
				leaf detail {
					type string;
				}
			}
		}
	'''

	@Test def void testMappedExtensionDefinesActions() {
		val root = new File("./src/test/resources/extension-schema-nodes").canonicalFile
		ProjectConfigAdapter.install(resourceSet, new FileProjectConfig(root))
		load(EXTENSION_MODULE)
		val foo = load(USING_MODULE)
		val issues = validator.validate(foo)
		Assert.assertTrue(issues.join('\n'), issues.empty)
	}

	@Test def void testUnmappedExtensionKeepsDefaultBehavior() {
		load(EXTENSION_MODULE)
		val foo = load(USING_MODULE)
		val issues = validator.validate(foo)
		Assert.assertTrue(issues.join('\n'), issues.exists[code == IssueCodes.DUPLICATE_NAME])
		Assert.assertTrue(issues.join('\n'), issues.exists[message.contains("Couldn't resolve reference")])
	}
}
