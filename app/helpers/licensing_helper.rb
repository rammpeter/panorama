# encoding: utf-8
module LicensingHelper
  def license_list
    [
        {:sid=>"ALPHA1",    :host=>nil,         :port=>"1527" },
        {:sid=>"ALPHA2",    :host=>nil,         :port=>"1527" },
        {:sid=>"BLDTEST2",  :host=>nil,         :port=>nil    },  # Performance-Test AMOS Russland
        {:sid=>"CBT",       :host=>nil,         :port=>"1523" },
        {:sid=>"COBRA",     :host=>nil,         :port=>"1522" },
        {:sid=>"EKA1",      :host=>nil,         :port=>nil    },  # EKR Abnahme
        {:sid=>"EKA2",      :host=>nil,         :port=>nil    },  # EKR Abnahme
        {:sid=>"EKP1",      :host=>nil,         :port=>nil    },  # EKR Produktion
        {:sid=>"EKP2",      :host=>nil,         :port=>nil    },  # EKR Produktion
        {:sid=>"HAZADD",    :host=>nil,         :port=>"1524" },
        {:sid=>"HDL1",      :host=>nil,         :port=>"1522" },
        {:sid=>"MMDBPR1",   :host=>nil,         :port=>"1521" },
        {:sid=>"MMDBPR2",   :host=>nil,         :port=>"1521" },
        {:sid=>"NOADB1",    :host=>"noaa",      :port=>"1522" },
        {:sid=>"NOADB2",    :host=>"noab",      :port=>"1522" },
        {:sid=>"NOADB1",    :host=>"dm03db01",  :port=>"1521" },
        {:sid=>"NOADB2",    :host=>"dm03db02",  :port=>"1521" },
        {:sid=>"RUSPRO3",   :host=>nil,         :port=>nil    },  # Produktion AMOS Russland
        {:sid=>"SPPROD01",  :host=>nil,         :port=>nil    },
        {:sid=>"SPPROD02",  :host=>nil,         :port=>nil    },
        {:sid=>"TRANSTOR",  :host=>nil,         :port=>"1521" },
        {:sid=>"TR1",       :host=>nil,         :port=>"1521" },
        {:sid=>"TR2",       :host=>nil,         :port=>"1521" },
        {:sid=>"WSI01",     :host=>nil,         :port=>nil    },
    ]
  end

end