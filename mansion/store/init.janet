(import tahani :as t)
(import mansion/utils :as u)

(defn- _make-index [self field data]
  (string field (u/hash2hex data (self :ctx) (self :hash-count))))

(defn- _create [self]
  (put self :db (t/open (self :name) :eie))
  (def batch (t/batch/create))
  (:put batch "hash-count" (string (marshal (self :hash-count))))
  (:put batch "to-index" (string (marshal (self :to-index))))
  (:put batch "ctx" (self :ctx))
  (:put batch "counter" "0")
  (loop [i :in (self :to-index)]
    (:put batch
          (string i (string/repeat "0" (+ (* (self :hash-count) 2) 1)))
           "\0"))
  (:_write self batch)
  (:destroy batch)
  self)

(defn- _open [self]
  (def db (t/open (self :name)))
  (put self :db db)
  (def batch (t/batch/create))
  (put self :hash-count (unmarshal (:get db "hash-count")))
  (put self :to-index (unmarshal (:get db "to-index")))
  (put self :ctx (:get db "ctx"))
  (:_write self batch)
  (:destroy batch)
  self)

(defn close [self]
  (:close (self :db)))

(defn- _get [self id]
   (-?> (:get (self :db) id) (unmarshal)))

(defn- _write [self batch]
   (:write batch (self :db)))

(defn- save [self data]
  (let [md (freeze (marshal data))
        id (-> (self :db) (:get "counter") (scan-number) (inc) (string))
        batch (t/batch/create)]
    (:put batch "counter" id)
    (:put batch id md)
    (each f (self :to-index)
      (if-let [d (get data f)]
        (let [mf (:_make-index self f d)
              start (string mf "0")]
          (unless (:get (self :db) start) (:put batch start d))
          (:put batch (string mf id) "\0"))))
    (:_write self batch)
    (:destroy batch)
    id))

(defn- load [self id] (:_get self id))

(defn- find-by [self field term &opt populate?]
  (assert (find |(= $ field) (self :to-index)))
  (default populate? false)
  (def ids @[])
  (let [mf (:_make-index self field term)
        start (string mf "0")
        iter (t/iterator/create (self :db))
        id-start (+ (length field) (* 2 (self :hash-count)))]
    (:seek iter start)
    (while (:valid? iter)
      (:next iter)
      (def k (:key iter))
      (if-let [id (and (string/has-prefix? mf k) (string/slice k id-start))]
        (array/push ids id) (break)))
    (case populate?
      :iter (seq [id :in ids] (:seek iter id) (unmarshal (:value iter)))
      :load (seq [id :in ids] (:load self id))
      ids)))

(def Store
  @{:name nil
    :to-index nil
    :ctx "-tahani-"
    :hash-count 16
    :_db nil
    :_make-index _make-index
    :_get _get
    :_write _write
    :_create _create
    :_open _open
    :close close
    :save save
    :load load
    :find-by find-by})

(defn create [name &opt to-index]
  (assert (string? name))
  (assert (and (tuple? to-index) (all |(keyword? $) to-index)))
  (default to-index [])
  (:_create
   (-> @{}
       (table/setproto Store)
       (merge-into {:name name :to-index to-index}))))

(defn open [name]
  (:_open
   (-> @{} (table/setproto Store) (put :name name))))
