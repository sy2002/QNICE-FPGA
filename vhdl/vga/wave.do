onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/clk_i
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/sprite_enable_i
add wave -noupdate -expand -group vga_sprite -radix unsigned /tb_vga_sprite/i_vga_sprite/pixel_x_i
add wave -noupdate -expand -group vga_sprite -radix unsigned /tb_vga_sprite/i_vga_sprite/pixel_y_i
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/color_i
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/config_addr_o
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/config_data_i
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/palette_addr_o
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/palette_data_i
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/bitmap_addr_o
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/bitmap_data_i
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/color_o
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/delay_o
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/stage0
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/stage1
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/stage2
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/scanline_wr_addr
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/scanline_wr_data
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/scanline_wr_en
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/scanline_rd_addr
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/scanline_rd_data
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/color_d
add wave -noupdate -expand -group vga_sprite /tb_vga_sprite/i_vga_sprite/color_s
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/wr_addr_i
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/wr_data_i
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/rd_addr_i
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/rd_data_o
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/wr_offset
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/rd_offset
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/data_concat
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/data_rot
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/enable_concat
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/enable_rot
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/a_addr
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/a_wr_data
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/a_wr_en
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/a_rd_data
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/b_addr
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/b_wr_en
add wave -noupdate -group vga_scanline /tb_vga_sprite/i_vga_sprite/i_vga_scanline/b_wr_data
add wave -noupdate -expand -group vga_blockram_with_byte_enable /tb_vga_sprite/i_vga_sprite/i_vga_scanline/i_vga_blockram_with_byte_enable/a_addr_i
add wave -noupdate -expand -group vga_blockram_with_byte_enable /tb_vga_sprite/i_vga_sprite/i_vga_scanline/i_vga_blockram_with_byte_enable/a_wr_data_i
add wave -noupdate -expand -group vga_blockram_with_byte_enable /tb_vga_sprite/i_vga_sprite/i_vga_scanline/i_vga_blockram_with_byte_enable/a_wr_en_i
add wave -noupdate -expand -group vga_blockram_with_byte_enable /tb_vga_sprite/i_vga_sprite/i_vga_scanline/i_vga_blockram_with_byte_enable/a_rd_data_o
add wave -noupdate -expand -group vga_blockram_with_byte_enable /tb_vga_sprite/i_vga_sprite/i_vga_scanline/i_vga_blockram_with_byte_enable/b_addr_i
add wave -noupdate -expand -group vga_blockram_with_byte_enable /tb_vga_sprite/i_vga_sprite/i_vga_scanline/i_vga_blockram_with_byte_enable/b_wr_data_i
add wave -noupdate -expand -group vga_blockram_with_byte_enable /tb_vga_sprite/i_vga_sprite/i_vga_scanline/i_vga_blockram_with_byte_enable/b_wr_en_i
add wave -noupdate -expand -group vga_blockram_with_byte_enable /tb_vga_sprite/i_vga_sprite/i_vga_scanline/i_vga_blockram_with_byte_enable/b_rd_data_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2075281086 fs} 0}
quietly wave cursor active 1
configure wave -namecolwidth 205
configure wave -valuecolwidth 718
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {2038759208 fs} {2265041610 fs}
