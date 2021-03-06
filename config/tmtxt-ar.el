;;; Config specific for working with AR project

;;; path to connect repo
(defconst AR-CONNECT-PATH "~/Projects/agencyrevolution/connect")

;;; list of frontend services
(defconst AR-FRONTEND-SERVICES (-> AR-CONNECT-PATH
                                   (s-concat "/frontend")
                                   (directory-files)))

;;; list of nodejs services
(defconst AR-NODE-SERVICES (-> AR-CONNECT-PATH
                               (s-concat "/nodejs")
                               (directory-files)))

;;; list of golang services
;;; golang services need .golang suffix
(defconst AR-GOLANG-SERVICES (--> AR-CONNECT-PATH
                                  (s-concat it "/golang")
                                  (directory-files it)
                                  (-map (lambda (service) (s-concat service ".golang")) it)))

;;; all services
(defconst AR-ALL-SERVICES (-distinct (-concat AR-FRONTEND-SERVICES
                                              AR-NODE-SERVICES
                                              AR-GOLANG-SERVICES)))

(defun ar/select-service ()
  "Ask for user input for 1 service name from one the above"
  (helm-comp-read "Select service to tag: " AR-ALL-SERVICES))

(defun ar/select-version-type ()
  "Ask for user input 1 version type"
  (helm-comp-read "Select next version type: " (list "patch" "minor" "major")))

(defun ar/select-tag-type ()
  "Ask for user input 1 tag type"
  (helm-comp-read "Select next tag type: " (list "unit-test" "cascading-unit-test" "hot-fix")))

(defun ar/get-version-from-tag (tag-name)
  "Get the version from tag name"
  (->> tag-name
       (s-match "[0-9]+\.[0-9]+\.[0-9]+")
       (-last-item)))

(defun ar/compare-tags (tag1 tag2)
  "Compare the 2 input tag: microservice.realm-v0.0.3 and microservice.realm-v0.1.2
   Return true if tag1 < tag2, false if tag1 > tag2. Return true in the example above
   "
  (let* ((version1 (ar/get-version-from-tag tag1))
         (version2 (ar/get-version-from-tag tag2)))
    (version< version1 version2)))

(defun ar/get-latest-tag (service-name)
  "Get the latest tag for one service name"
  (let ((default-directory AR-CONNECT-PATH)
        (regex (s-concat service-name "-v")))
    (--> "tag"
         ;; get all git tags for this repo
         (magit-git-lines it)
         ;; filter to the tags that match the service name
         (-filter (lambda (tag) (s-contains? regex tag)) it)
         ;; sort the tags, the oldest first
         (-sort 'ar/compare-tags it)
         ;; pick the last tag (the latest one)
         (-last-item it)
         )))

(defun ar/get-next-major-tags (current-version)
  (->> current-version
       (version-to-list)
       ;; increase the major version
       (-update-at 0 '1+)
       ;; reset minor and patch to 0
       (-replace-at 1 0)
       (-replace-at 2 0)
       ;; join back to a string
       (-map 'number-to-string)
       (s-join ".")
       ))

(defun ar/get-next-minor-tags (current-version)
  (->> current-version
       (version-to-list)
       ;; increase the minor version
       (-update-at 1 '1+)
       ;; reset patch to 0
       (-replace-at 2 0)
       ;; join back to a string
       (-map 'number-to-string)
       (s-join ".")
       ))

(defun ar/get-next-patch-tags (current-version)
  (->> current-version
       (version-to-list)
       ;; increase the patch version
       (-update-at 2 '1+)
       ;; join back to a string
       (-map 'number-to-string)
       (s-join ".")
       ))

(defun ar/get-next-version (version version-type)
  "Get the next version
   version-type: major/minor/patch
   Ex: version: 4.5.6 -> next major 5.0.0"
  (cond
   ((string= version-type "major") (ar/get-next-major-tags version))
   ((string= version-type "minor") (ar/get-next-minor-tags version))
   (t (ar/get-next-patch-tags version))))

(defun ar/get-tag-suffix (tag-type)
  "Get tag suffix"
  (cond
   ((string= tag-type "unit-test") "-unit-test")
   ((string= tag-type "cascading-unit-test") "-cascading-unit-test")
   (t "")))

(defun ar/get-next-tag (service-name tag-name version-type tag-type)
  "Get next tag for the input tag-name
   service-name: microservice.realm
   tag-name: microservice.realm-v0.0.3
   version-type: major
   tag-type: unit-test
   => microservice.realm-v1.0.0-unit-test"
  (let* ((tag-name-without-version (s-concat service-name "-v"))
         (next-version (-> tag-name
                           (ar/get-version-from-tag)
                           (ar/get-next-version version-type)))
         (tag-suffix (ar/get-tag-suffix tag-type)))
    (s-concat tag-name-without-version next-version tag-suffix)))

(defun ar/increase-tag-handler (service-name version-type tag-type)
  (let* ((next-tag (--> service-name
                        (ar/get-latest-tag it)
                        (ar/get-next-tag service-name it version-type tag-type)))
         (default-directory AR-CONNECT-PATH))
    (magit-tag next-tag "HEAD")
    (message next-tag)))

(defun ar/increase-tag ()
  "Interactive function for increasing tag in general"
  (interactive)
  (let ((service-name (ar/select-service))
        (version-type (ar/select-version-type))
        (tag-type (ar/select-tag-type)))
    (ar/increase-tag-handler service-name version-type tag-type)))

(defun ar/increase-major-tag ()
  ""
  (interactive)
  (let ((service-name (ar/select-service))
        (tag-type (ar/select-tag-type)))
    (ar/increase-tag-handler service-name "major" tag-type)))

(defun ar/increase-minor-tag ()
  ""
  (interactive)
  (let ((service-name (ar/select-service))
        (tag-type (ar/select-tag-type)))
    (ar/increase-tag-handler service-name "minor" tag-type)))

(defun ar/increase-patch-tag ()
  ""
  (interactive)
  (let ((service-name (ar/select-service))
        (tag-type (ar/select-tag-type)))
    (ar/increase-tag-handler service-name "patch" tag-type)))

(provide 'tmtxt-ar)
