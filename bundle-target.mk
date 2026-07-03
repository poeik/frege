#
# ─────────────────────────────────────────────────────────────────────────
# Creates and unsigned bundle to ship to Maven Central.
#
# Included from the main Makefile:   include Maven.mk
#
# Depends on these variables/targets defined by the parent Makefile:
#   $(RM)  $(MKDIR)  $(CP)  $(JAVA)   and the  fregec.jar  target.
#
# Targets:
#   make bundle       assemble central-bundle.zip
#   make bundleclean  remove all generated release artifacts
#

.PHONY: bundle bundleclean

GROUP        = org.frege-lang
GROUPPATH    = org/frege-lang
ARTIFACT     = frege
VERSION      = 3.25.84
BASE         = $(ARTIFACT)-$(VERSION)

BUNDLE       = bundle
BUNDLE_DIR   = $(BUNDLE)/$(GROUPPATH)/$(ARTIFACT)/$(VERSION)
BUNDLE_ZIP   = central-bundle.zip

# checksum helpers: prefer GNU tools, fall back to BSD/macOS variants
MD5  = `which md5sum  >/dev/null 2>&1 && echo "md5sum"  || echo "md5 -q"`
SHA1 = `which sha1sum >/dev/null 2>&1 && echo "sha1sum" || echo "shasum -a 1"`

# ---- main jar ----------------------------------------
# The existing 'fregec.jar' target packages the source tree (incl. *.java files).
# For the bundle we only want the class files.
$(BASE).jar: fregec.jar
	@echo "\033[1;43mMaking $@ (classes only)\033[0m"
	$(RM) classes-tmp && $(MKDIR) classes-tmp
	cd classes-tmp && jar xf ../fregec.jar
	# drop everything that is not a .class or the manifest
	cd classes-tmp && find . -type f ! -name '*.class' ! -path './META-INF/MANIFEST.MF' -delete
	cd classes-tmp && jar -cfm ../$@ META-INF/MANIFEST.MF .
	$(RM) classes-tmp

# ---- sources jar ---------------------------------------
$(BASE)-sources.jar:
	@echo "\033[1;43mMaking $@ (.fr only)\033[0m"
	find frege -name '*.fr' > .srclist
	jar -cf $@ @.srclist
	$(RM) .srclist

# ---- javadoc jar: frege.tools.Doc output ---------
$(BASE)-javadoc.jar: fregec.jar
	@echo "\033[1;43mMaking $@\033[0m"
	$(RM) javadoc-tmp && $(MKDIR) javadoc-tmp
	$(JAVA) -cp fregec.jar frege.tools.Doc -d javadoc-tmp fregec.jar || true
	@echo "See https://github.com/Frege/frege" > javadoc-tmp/README.txt
	jar -cf $@ -C javadoc-tmp .
	$(RM) javadoc-tmp

# ---- POM: generated from template, version injected from $(VERSION) ------
$(BASE).pom: frege.pom.template
	@echo "\033[1;43mMaking $@\033[0m"
	sed 's/@VERSION@/$(VERSION)/g' frege.pom.template > $@

# ---- assemble the bundle ------------------------------------------------
bundle: $(BASE).jar $(BASE)-sources.jar $(BASE)-javadoc.jar $(BASE).pom
	@echo "\033[1;42mMaking $@\033[0m"
	$(RM) $(BUNDLE) $(BUNDLE_ZIP)
	$(MKDIR) $(BUNDLE_DIR)
	$(CP) $(BASE).jar               $(BUNDLE_DIR)/$(BASE).jar
	$(CP) $(BASE)-sources.jar       $(BUNDLE_DIR)/$(BASE)-sources.jar
	$(CP) $(BASE)-javadoc.jar       $(BUNDLE_DIR)/$(BASE)-javadoc.jar
	$(CP) $(BASE).pom               $(BUNDLE_DIR)/$(BASE).pom
	@echo "Generating checksums ..."
	cd $(BUNDLE_DIR) && for f in $(BASE).jar $(BASE)-sources.jar $(BASE)-javadoc.jar $(BASE).pom ; do \
	    $(MD5)  $$f | cut -d' ' -f1 > $$f.md5 ; \
	    $(SHA1) $$f | cut -d' ' -f1 > $$f.sha1 ; \
	done
	cd $(BUNDLE) && zip -q -r ../$(BUNDLE_ZIP) .
	@echo ""
	@echo "Created unsigned $(BUNDLE_ZIP)."
	@echo ""

bundleclean:
	@echo "\033[1;42mMaking $@\033[0m"
	$(RM) $(BUNDLE) $(BUNDLE_ZIP) $(BASE).jar $(BASE)-sources.jar $(BASE)-javadoc.jar $(BASE).pom
