require 'spec_helper'

module Omnibus
  describe Ohai do
    context 'using dot notation' do
      it 'does not raise an exception' do
        expect { Ohai.kernel }.to_not raise_error
        expect { Ohai.kernel.machine }.to_not raise_error
      end
    end

    context 'using hash notation' do
      it 'allows fetching values by hash notation' do
        expect { Ohai['kernel'] }.to_not raise_error
        expect { Ohai['kernel']['machine'] }.to_not raise_error
      end
    end
  end
end
