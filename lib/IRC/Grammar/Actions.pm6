class IRC::Grammar::Actions {
    method class     ($/) { $/.make: ~$/                            }
    method rules     ($/) { $/.make: ~$/                            }
    method pair      ($/) { $/.make: $<class>.made => $<rules>.made }
    method TOP       ($/) { $/.make: $<pair>».made                  }
}
