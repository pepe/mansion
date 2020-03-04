(import test/helper :prefix "" :exit true)

(import tahani :as t)

(import ../mansion/store :as ms)
(import ../mansion/utils :as mu)

(start-suite 0)

(def db-name "peopletest")

(defer (t/manage/destroy db-name)
  (with [s (ms/create db-name @{:to-index [:name :job :pet]})]
    (assert s "Store is not created")
    (def id (:save s {:name "Pepe" :job "Programmer" :pet "Cat"}))
    (assert id "Record is not saved")
    (assert (string? id) "Record id is not string")
    (assert (= id "1") "Id is not 1")
    (def r (:load s id))
    (assert r "Record is not loaded")
    (assert (struct? r) "Record is not struct")
    (assert (= (r :name) "Pepe") "Record has bad name")
    (with [batch (t/batch/create) |(:write s $)]
      (:save s {:name "Jose" :job "Programmer" :pet "Cat"} batch)
      (:save s {:name "Karl" :job "Gardener" :pet "Dog"} batch)
      (:save s {:name "Pepe" :job "Gardener" :pet "Dog"} batch)
      (:save s {:name "Joker" :job "Gardener" :pet "" :good-deeds []} batch))
    (def rs (:retrieve s {:name "Pepe"}))
    (assert (array? rs) "Records are not found by retrieve")
    (assert (= (length (first rs)) 2) "Not all records are found by retrieve")
    (assert (deep= (first rs) @["1" "4"]) "Not right ids found")
    (def rsi (:retrieve s {:name "Pepe"} {:populate? true}))
    (assert (= (length (first rsi)) 2) "Not all records are found by retrieve with iterator population")
    (assert (deep= (first rsi) @[{:name "Pepe" :job "Programmer" :pet "Cat"} {:name "Pepe" :job "Gardener" :pet "Dog"}]) "Not right records found")
    (:save s ["1" {:name "Pepek" :job "Programmer" :pet "Cat"}])
    (assert (= ((:load s "1") :name) "Pepek") "Record not updated")
    (def rst (:retrieve s @[@["1" "2"]]))
    (assert (deep= (first rst) @[{:name "Pepek" :job "Programmer" :pet "Cat"} {:name "Jose" :job "Programmer" :pet "Cat"}]) "NOt right records retrieevd")
    (def rsa (:retrieve s :all @{}))
    (assert (deep= (first rsa) @["5" "4" "3" "2" "1"]) "Not right ids retrieevd")
    (def rsai (:retrieve s :all @{:populate? true}))
    (assert (deep= (first rsai)
                   @[{:name "Joker" :job "Gardener" :pet "" :good-deeds []}
                     {:name "Pepe" :job "Gardener" :pet "Dog"}
                     {:name "Karl" :job "Gardener" :pet "Dog"}
                     {:name "Jose" :job "Programmer" :pet "Cat"}
                     {:name "Pepek" :job "Programmer" :pet "Cat"}])
     "Not right records retrieved")
    (def rsl (:retrieve s :all @{:populate? true :limit 2}))
    (assert (= (length (first rsl)) 2) "Retrieve is not limited"))
  (with [os (ms/open db-name)]
    (assert (:load os "1") "First record is not in reopened store")
    (def rsi (:retrieve os {:name "Pepe"} {:populate? true}))
    (assert (= (length (first rsi)) 2) "Not all records are found by retrieve with iterator population")
    (assert (deep= (first rsi) @[{:name "Pepek" :job "Programmer" :pet "Cat"} {:name "Pepe" :job "Gardener" :pet "Dog"}]) "Not right records found")))

(end-suite)

