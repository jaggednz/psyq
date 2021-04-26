local shift_reg = {
}

shift_reg.length = 16
shift_reg.contents = {}

function shift_reg:new(length)
  self.length = length
  for i = 1,self.length do
    self.contents[i] = 0
  end
  
  return self
end

function shift_reg:clk()
  
end

return shift_reg;